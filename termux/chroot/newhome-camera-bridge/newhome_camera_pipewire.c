#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include <pipewire/pipewire.h>
#include <spa/buffer/meta.h>
#include <spa/param/buffers.h>
#include <spa/param/video/format-utils.h>
#include <spa/utils/result.h>

#define SOCKET_NAME "newhome.camera"
#define NH_MAGIC 0x3143484eU
#define NH_VERSION 1
#define NH_MESSAGE_SIZE 28
#define NH_TYPE_START 1
#define NH_TYPE_STOP 2
#define NH_TYPE_DONE 3
#define NH_TYPE_HELLO 0x80
#define NH_TYPE_SHM 0x81
#define NH_TYPE_READY 0x82
#define NH_TYPE_ERROR 0xff
#define NH_FORMAT_NV21 2

struct __attribute__((packed)) nh_message {
    uint32_t magic;
    uint8_t version;
    uint8_t type;
    uint8_t camera;
    uint8_t slot;
    uint32_t width;
    uint32_t height;
    uint32_t format;
    uint32_t value;
    uint32_t generation;
};
_Static_assert(sizeof(struct nh_message) == NH_MESSAGE_SIZE, "protocol size mismatch");

struct app {
    int sock;
    pthread_t reader_thread;
    pthread_mutex_t send_lock;
    pthread_mutex_t frame_lock;
    bool running;
    int camera_index;
    uint32_t request_width;
    uint32_t request_height;
    uint32_t width;
    uint32_t height;
    uint32_t generation;
    size_t slot_bytes;
    int shm_fd;
    uint8_t *shm;
    size_t shm_bytes;
    uint8_t *frame;
    size_t frame_size;
    struct pw_main_loop *loop;
    struct spa_source *timer;
    struct pw_stream *stream;
    struct spa_hook stream_listener;
    bool pipewire_streaming;
    bool have_frame;
    uint64_t ready_count;
    uint64_t process_count;
    uint32_t sequence;
};

static struct app *g_app;

static int send_all(int fd, const void *buf, size_t len)
{
    const uint8_t *p = buf;
    size_t off = 0;
    while (off < len) {
        ssize_t n = send(fd, p + off, len - off, MSG_NOSIGNAL);
        if (n < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        off += (size_t)n;
    }
    return 0;
}

static int recv_all(int fd, void *buf, size_t len)
{
    uint8_t *p = buf;
    size_t off = 0;
    while (off < len) {
        ssize_t n = recv(fd, p + off, len - off, 0);
        if (n == 0) return 0;
        if (n < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        off += (size_t)n;
    }
    return 1;
}

static void fill_header(struct nh_message *m, uint8_t type)
{
    memset(m, 0, sizeof(*m));
    m->magic = NH_MAGIC;
    m->version = NH_VERSION;
    m->type = type;
}

static int send_message(struct app *a, struct nh_message *m)
{
    int rc;
    pthread_mutex_lock(&a->send_lock);
    rc = send_all(a->sock, m, sizeof(*m));
    pthread_mutex_unlock(&a->send_lock);
    return rc;
}

static int send_start(struct app *a)
{
    struct nh_message m;
    fill_header(&m, NH_TYPE_START);
    m.camera = (uint8_t)a->camera_index;
    m.width = a->request_width;
    m.height = a->request_height;
    return send_message(a, &m);
}

static int send_stop(struct app *a)
{
    struct nh_message m;
    fill_header(&m, NH_TYPE_STOP);
    m.camera = (uint8_t)a->camera_index;
    return send_message(a, &m);
}

static int send_done(struct app *a, uint8_t slot, uint32_t generation)
{
    struct nh_message m;
    fill_header(&m, NH_TYPE_DONE);
    m.camera = (uint8_t)a->camera_index;
    m.slot = slot;
    m.generation = generation;
    return send_message(a, &m);
}

static int recv_message_with_fd(int fd, struct nh_message *m, int *received_fd)
{
    struct iovec iov = { .iov_base = m, .iov_len = sizeof(*m) };
    union {
        char buf[CMSG_SPACE(sizeof(int))];
        struct cmsghdr align;
    } control;
    struct msghdr msg;
    memset(&msg, 0, sizeof(msg));
    msg.msg_iov = &iov;
    msg.msg_iovlen = 1;
    msg.msg_control = control.buf;
    msg.msg_controllen = sizeof(control.buf);

    size_t off = 0;
    int got_fd = -1;
    while (off < sizeof(*m)) {
        iov.iov_base = (uint8_t *)m + off;
        iov.iov_len = sizeof(*m) - off;
        ssize_t n = recvmsg(fd, &msg, 0);
        if (n == 0) return 0;
        if (n < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        if (got_fd < 0) {
            for (struct cmsghdr *c = CMSG_FIRSTHDR(&msg); c; c = CMSG_NXTHDR(&msg, c)) {
                if (c->cmsg_level == SOL_SOCKET && c->cmsg_type == SCM_RIGHTS &&
                    c->cmsg_len >= CMSG_LEN(sizeof(int))) {
                    memcpy(&got_fd, CMSG_DATA(c), sizeof(int));
                    break;
                }
            }
        }
        off += (size_t)n;
        msg.msg_control = NULL;
        msg.msg_controllen = 0;
    }
    if (received_fd) *received_fd = got_fd;
    else if (got_fd >= 0) close(got_fd);
    return 1;
}

static bool valid_message(const struct nh_message *m)
{
    return m->magic == NH_MAGIC && m->version == NH_VERSION;
}

static int connect_server(void)
{
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) return -1;
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    addr.sun_path[0] = '\0';
    const size_t name_len = strlen(SOCKET_NAME);
    memcpy(addr.sun_path + 1, SOCKET_NAME, name_len);
    socklen_t len = (socklen_t)(offsetof(struct sockaddr_un, sun_path) + 1 + name_len);
    if (connect(fd, (struct sockaddr *)&addr, len) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static void release_shm(struct app *a)
{
    if (a->shm && a->shm != MAP_FAILED) munmap(a->shm, a->shm_bytes);
    a->shm = NULL;
    a->shm_bytes = 0;
    if (a->shm_fd >= 0) close(a->shm_fd);
    a->shm_fd = -1;
}

static int adopt_shm(struct app *a, const struct nh_message *m, int fd)
{
    if (fd < 0 || m->format != NH_FORMAT_NV21 || m->width == 0 || m->height == 0 ||
        m->value == 0 || m->value > 256U * 1024U * 1024U) {
        if (fd >= 0) close(fd);
        return -1;
    }
    if ((size_t)m->value > SIZE_MAX / 2U ||
        (size_t)m->width > SIZE_MAX / (size_t)m->height) {
        close(fd);
        return -1;
    }
    size_t expected = (size_t)m->width * (size_t)m->height;
    if (expected > SIZE_MAX - expected / 2U) {
        close(fd);
        return -1;
    }
    expected += expected / 2U;
    if (expected > (size_t)m->value) {
        fprintf(stderr, "NewHome camera: shared slot smaller than frame\n");
        close(fd);
        return -1;
    }
    size_t total = (size_t)m->value * 2U;
    void *p = mmap(NULL, total, PROT_READ, MAP_SHARED, fd, 0);
    if (p == MAP_FAILED) {
        close(fd);
        return -1;
    }

    pthread_mutex_lock(&a->frame_lock);
    release_shm(a);
    a->shm_fd = fd;
    a->shm = p;
    a->shm_bytes = total;
    a->slot_bytes = m->value;
    a->width = m->width;
    a->height = m->height;
    a->generation = m->generation;
    a->have_frame = false;
    uint8_t *new_frame = realloc(a->frame, expected);
    if (!new_frame) {
        release_shm(a);
        pthread_mutex_unlock(&a->frame_lock);
        return -1;
    }
    a->frame = new_frame;
    a->frame_size = expected;
    memset(a->frame, 16, (size_t)a->width * a->height);
    memset(a->frame + (size_t)a->width * a->height, 128, expected - (size_t)a->width * a->height);
    pthread_mutex_unlock(&a->frame_lock);

    fprintf(stderr, "NewHome camera: shared memory %ux%u generation=%u\n",
            a->width, a->height, a->generation);
    return 0;
}

static void *reader_main(void *userdata)
{
    struct app *a = userdata;
    while (a->running) {
        struct nh_message m;
        int passed_fd = -1;
        int rc = recv_message_with_fd(a->sock, &m, &passed_fd);
        if (rc <= 0) break;
        if (!valid_message(&m)) {
            if (passed_fd >= 0) close(passed_fd);
            fprintf(stderr, "NewHome camera: invalid protocol message\n");
            break;
        }
        switch (m.type) {
        case NH_TYPE_SHM:
            if (adopt_shm(a, &m, passed_fd) < 0)
                fprintf(stderr, "NewHome camera: failed to map shared memory\n");
            passed_fd = -1;
            break;
        case NH_TYPE_READY:
            if (passed_fd >= 0) close(passed_fd);
            passed_fd = -1;
            if (m.slot > 1) break;
            pthread_mutex_lock(&a->frame_lock);
            if (a->shm && m.generation == a->generation && m.value <= a->slot_bytes &&
                a->frame && a->frame_size <= a->slot_bytes) {
                memcpy(a->frame, a->shm + (size_t)m.slot * a->slot_bytes, a->frame_size);
                a->have_frame = true;
                a->ready_count++;
                if (a->ready_count == 1 || a->ready_count % 300 == 0) {
                    fprintf(stderr, "NewHome camera: READY count=%llu generation=%u sample=%u/%u\n",
                            (unsigned long long)a->ready_count, a->generation,
                            a->frame[0], a->frame[a->frame_size / 2]);
                }
            }
            pthread_mutex_unlock(&a->frame_lock);
            send_done(a, m.slot, m.generation);
            break;
        case NH_TYPE_ERROR:
            if (passed_fd >= 0) close(passed_fd);
            passed_fd = -1;
            fprintf(stderr, "NewHome camera: Android bridge error=%u\n", m.value);
            break;
        default:
            if (passed_fd >= 0) close(passed_fd);
            passed_fd = -1;
            break;
        }
    }
    a->running = false;
    if (a->loop) pw_main_loop_quit(a->loop);
    return NULL;
}

static void on_stream_state_changed(void *userdata, enum pw_stream_state old,
                                    enum pw_stream_state state, const char *error)
{
    struct app *a = userdata;
    (void)old;
    if (state == PW_STREAM_STATE_ERROR) {
        fprintf(stderr, "NewHome camera: PipeWire stream error: %s\n", error ? error : "unknown");
        return;
    }
    bool streaming = state == PW_STREAM_STATE_STREAMING;
    fprintf(stderr, "NewHome camera: PipeWire state %s -> %s\n",
            pw_stream_state_as_string(old), pw_stream_state_as_string(state));
    if (streaming == a->pipewire_streaming) return;
    a->pipewire_streaming = streaming;
    if (streaming) {
        if (send_start(a) < 0) fprintf(stderr, "NewHome camera: START failed\n");
        struct timespec first = { .tv_sec = 0, .tv_nsec = 1 };
        struct timespec interval = { .tv_sec = 0, .tv_nsec = 33333333 };
        pw_loop_update_timer(pw_main_loop_get_loop(a->loop), a->timer,
                             &first, &interval, false);
    } else {
        pw_loop_update_timer(pw_main_loop_get_loop(a->loop), a->timer,
                             NULL, NULL, false);
        send_stop(a);
    }
}

static void on_timeout(void *userdata, uint64_t expirations)
{
    struct app *a = userdata;
    (void)expirations;
    pw_stream_trigger_process(a->stream);
}

static void on_param_changed(void *userdata, uint32_t id, const struct spa_pod *param)
{
    struct app *a = userdata;
    if (id != SPA_PARAM_Format || !param) return;
    uint8_t buffer[1024];
    struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
    const struct spa_pod *params[2];
    params[0] = spa_pod_builder_add_object(
        &b,
        SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers,
        SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(8, 2, 16),
        SPA_PARAM_BUFFERS_blocks, SPA_POD_Int(1),
        SPA_PARAM_BUFFERS_size, SPA_POD_Int((int)a->frame_size),
        SPA_PARAM_BUFFERS_stride, SPA_POD_Int((int)a->width),
        SPA_PARAM_BUFFERS_dataType, SPA_POD_CHOICE_FLAGS_Int((1 << SPA_DATA_MemPtr) | (1 << SPA_DATA_MemFd)));
    params[1] = spa_pod_builder_add_object(
        &b,
        SPA_TYPE_OBJECT_ParamMeta, SPA_PARAM_Meta,
        SPA_PARAM_META_type, SPA_POD_Id(SPA_META_Header),
        SPA_PARAM_META_size, SPA_POD_Int(sizeof(struct spa_meta_header)));
    pw_stream_update_params(a->stream, params, 2);
}

static void on_process(void *userdata)
{
    struct app *a = userdata;
    struct pw_buffer *pwb = pw_stream_dequeue_buffer(a->stream);
    if (!pwb) return;
    struct spa_buffer *buf = pwb->buffer;
    if (buf->n_datas < 1 || !buf->datas[0].data || !buf->datas[0].chunk) {
        pw_stream_queue_buffer(a->stream, pwb);
        return;
    }
    pthread_mutex_lock(&a->frame_lock);
    size_t n = a->frame_size;
    if (n > buf->datas[0].maxsize) n = buf->datas[0].maxsize;
    if (a->frame && n > 0) memcpy(buf->datas[0].data, a->frame, n);
    bool have_frame = a->have_frame;
    a->process_count++;
    uint64_t process_count = a->process_count;
    pthread_mutex_unlock(&a->frame_lock);
    buf->datas[0].chunk->offset = 0;
    buf->datas[0].chunk->size = (uint32_t)n;
    buf->datas[0].chunk->stride = (int32_t)a->width;
    buf->datas[0].chunk->flags = 0;
    struct spa_meta_header *header = spa_buffer_find_meta_data(
        buf, SPA_META_Header, sizeof(struct spa_meta_header));
    if (header) {
        header->flags = 0;
        header->pts = pw_stream_get_nsec(a->stream);
        header->seq = a->sequence++;
        header->dts_offset = 0;
    }
    if (process_count == 1 || process_count % 300 == 0) {
        fprintf(stderr, "NewHome camera: PROCESS count=%llu real=%s header=%s bytes=%zu\n",
                (unsigned long long)process_count, have_frame ? "yes" : "no",
                header ? "yes" : "no", n);
    }
    pw_stream_queue_buffer(a->stream, pwb);
}

static const struct pw_stream_events stream_events = {
    PW_VERSION_STREAM_EVENTS,
    .state_changed = on_stream_state_changed,
    .param_changed = on_param_changed,
    .process = on_process,
};

static int create_pipewire_source(struct app *a)
{
    a->loop = pw_main_loop_new(NULL);
    if (!a->loop) return -1;
    a->timer = pw_loop_add_timer(pw_main_loop_get_loop(a->loop), on_timeout, a);
    if (!a->timer) return -1;
    struct pw_properties *props = pw_properties_new(
        PW_KEY_MEDIA_CLASS, "Video/Source",
        PW_KEY_MEDIA_TYPE, "Video",
        PW_KEY_MEDIA_CATEGORY, "Capture",
        PW_KEY_MEDIA_ROLE, "Camera",
        PW_KEY_NODE_NAME, "newhome.camera",
        PW_KEY_NODE_DESCRIPTION, "NewHome Camera",
        PW_KEY_NODE_SUPPORTS_REQUEST, "1",
        NULL);
    a->stream = pw_stream_new_simple(
        pw_main_loop_get_loop(a->loop), "NewHome Camera", props, &stream_events, a);
    if (!a->stream) return -1;

    uint8_t buffer[1024];
    struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
    const struct spa_pod *params[1];
    params[0] = spa_pod_builder_add_object(
        &b,
        SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
        SPA_FORMAT_mediaType, SPA_POD_Id(SPA_MEDIA_TYPE_video),
        SPA_FORMAT_mediaSubtype, SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
        SPA_FORMAT_VIDEO_format, SPA_POD_Id(SPA_VIDEO_FORMAT_NV21),
        SPA_FORMAT_VIDEO_size, SPA_POD_Rectangle(&SPA_RECTANGLE(a->width, a->height)),
        SPA_FORMAT_VIDEO_framerate, SPA_POD_Fraction(&SPA_FRACTION(30, 1)));
    int rc = pw_stream_connect(
        a->stream, PW_DIRECTION_OUTPUT, PW_ID_ANY,
        PW_STREAM_FLAG_DRIVER | PW_STREAM_FLAG_MAP_BUFFERS, params, 1);
    if (rc < 0) {
        fprintf(stderr, "NewHome camera: pw_stream_connect: %s\n", spa_strerror(rc));
        return -1;
    }
    return 0;
}

static void handle_signal(int sig)
{
    (void)sig;
    if (!g_app) return;
    g_app->running = false;
    if (g_app->loop) pw_main_loop_quit(g_app->loop);
}

static int wait_initial_shm(struct app *a, int camera_count)
{
    if (a->camera_index < 0 || a->camera_index >= camera_count) {
        fprintf(stderr, "NewHome camera: camera index %d out of range (count=%d)\n",
                a->camera_index, camera_count);
        return -1;
    }
    if (send_start(a) < 0) return -1;
    for (;;) {
        struct nh_message m;
        int passed_fd = -1;
        int rc = recv_message_with_fd(a->sock, &m, &passed_fd);
        if (rc <= 0 || !valid_message(&m)) {
            if (passed_fd >= 0) close(passed_fd);
            return -1;
        }
        if (m.type == NH_TYPE_SHM) {
            if (adopt_shm(a, &m, passed_fd) < 0) return -1;
            send_stop(a);
            return 0;
        }
        if (passed_fd >= 0) close(passed_fd);
        if (m.type == NH_TYPE_ERROR) {
            fprintf(stderr, "NewHome camera: Android bridge error=%u during startup\n", m.value);
            return -1;
        }
    }
}

static void usage(const char *argv0)
{
    fprintf(stderr,
        "usage: %s [--camera N] [--width W] [--height H]\n"
        "defaults: camera=0 width=1280 height=720\n",
        argv0);
}

int main(int argc, char **argv)
{
    struct app a;
    memset(&a, 0, sizeof(a));
    a.sock = -1;
    a.shm_fd = -1;
    a.camera_index = 0;
    a.request_width = 1280;
    a.request_height = 720;
    pthread_mutex_init(&a.send_lock, NULL);
    pthread_mutex_init(&a.frame_lock, NULL);

    for (int i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--camera") && i + 1 < argc) a.camera_index = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--width") && i + 1 < argc) a.request_width = (uint32_t)atoi(argv[++i]);
        else if (!strcmp(argv[i], "--height") && i + 1 < argc) a.request_height = (uint32_t)atoi(argv[++i]);
        else { usage(argv[0]); return 2; }
    }

    for (int attempt = 0; attempt < 600; ++attempt) {
        a.sock = connect_server();
        if (a.sock >= 0) break;
        usleep(100000);
    }
    if (a.sock < 0) {
        fprintf(stderr, "NewHome camera: cannot connect to Android bridge @%s\n", SOCKET_NAME);
        return 1;
    }

    struct nh_message hello;
    if (recv_all(a.sock, &hello, sizeof(hello)) != 1 || !valid_message(&hello) || hello.type != NH_TYPE_HELLO) {
        fprintf(stderr, "NewHome camera: invalid HELLO\n");
        close(a.sock);
        return 1;
    }
    int camera_count = (int)hello.value;
    fprintf(stderr, "NewHome camera: Android reports %d camera(s)\n", camera_count);

    if (wait_initial_shm(&a, camera_count) < 0) {
        close(a.sock);
        release_shm(&a);
        free(a.frame);
        return 1;
    }

    pw_init(&argc, &argv);
    a.running = true;
    if (pthread_create(&a.reader_thread, NULL, reader_main, &a) != 0) {
        fprintf(stderr, "NewHome camera: cannot start reader thread\n");
        return 1;
    }
    if (create_pipewire_source(&a) < 0) {
        a.running = false;
        shutdown(a.sock, SHUT_RDWR);
        pthread_join(a.reader_thread, NULL);
        return 1;
    }

    g_app = &a;
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    fprintf(stderr, "NewHome camera: PipeWire Video/Source ready (%ux%u)\n", a.width, a.height);
    pw_main_loop_run(a.loop);

    a.running = false;
    send_stop(&a);
    shutdown(a.sock, SHUT_RDWR);
    pthread_join(a.reader_thread, NULL);
    if (a.stream) pw_stream_destroy(a.stream);
    if (a.loop) pw_main_loop_destroy(a.loop);
    pw_deinit();
    release_shm(&a);
    free(a.frame);
    if (a.sock >= 0) close(a.sock);
    pthread_mutex_destroy(&a.send_lock);
    pthread_mutex_destroy(&a.frame_lock);
    return 0;
}
