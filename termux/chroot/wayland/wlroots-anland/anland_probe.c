#define _GNU_SOURCE
#include <errno.h>
#include <inttypes.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "display_producer.h"

static volatile sig_atomic_t running = 1;

static void on_signal(int signo) {
    (void)signo;
    running = 0;
}

static void on_fallback(void *userdata) {
    (void)userdata;
    fprintf(stderr, "[anland-probe] consumer disconnected; fallback resumed\n");
}

static const char *input_type_name(uint32_t type) {
    switch (type) {
    case INPUT_TYPE_TOUCH: return "touch";
    case INPUT_TYPE_KEY: return "key";
    case INPUT_TYPE_POINTER_MOTION: return "pointer-motion";
    case INPUT_TYPE_POINTER_BUTTON: return "pointer-button";
    case INPUT_TYPE_POINTER_AXIS: return "pointer-axis";
    case INPUT_TYPE_TOUCH_FRAME: return "touch-frame";
#ifdef INPUT_TYPE_SCREEN_REFRESH_RATE
    case INPUT_TYPE_SCREEN_REFRESH_RATE: return "refresh-rate";
#endif
#ifdef INPUT_TYPE_RESOURCE
    case INPUT_TYPE_RESOURCE: return "resource";
#endif
#ifdef INPUT_TYPE_CLIPBOARD_DATA
    case INPUT_TYPE_CLIPBOARD_DATA: return "clipboard";
#endif
#ifdef INPUT_TYPE_TEXT_COMMIT
    case INPUT_TYPE_TEXT_COMMIT: return "text-commit";
#endif
#ifdef INPUT_TYPE_TEXT_PREEDIT
    case INPUT_TYPE_TEXT_PREEDIT: return "text-preedit";
#endif
    default: return "other";
    }
}

static void print_buffers(display_ctx *ctx) {
    int count = get_buf_count(ctx);
    printf("[anland-probe] buffers=%d selected=%d\n", count, get_selected_idx(ctx));
    for (int i = 0; i < count; ++i) {
        struct buf_info info;
        memset(&info, 0, sizeof(info));
        int fd = get_dmabuf_fd_at(ctx, i);
        if (get_dmabuf_info_at(ctx, i, &info) < 0) {
            printf("  [%d] fd=%d metadata=unavailable\n", i, fd);
            continue;
        }
        printf("  [%d] fd=%d stride=%u format=%u modifier=0x%" PRIx64 " offset=%u",
               i, fd, info.stride, info.format, (uint64_t)info.modifier, info.offset);
#ifdef ANLAND_BUF_INFO_HAS_DIMENSIONS
        printf(" size=%ux%u", info.width, info.height);
#endif
        putchar('\n');
    }
    fflush(stdout);
}

static int wait_for_consumer(display_ctx *ctx, int timeout_seconds) {
    const struct timespec delay = { .tv_sec = 0, .tv_nsec = 200000000L };
    int ticks = timeout_seconds > 0 ? timeout_seconds * 5 : -1;

    while (running && is_fallback(ctx) && ticks != 0) {
        if (try_exit_fallback(ctx) == 0 && !is_fallback(ctx)) {
            printf("[anland-probe] consumer connected\n");
            print_buffers(ctx);
            return 0;
        }
        if (ticks > 0) {
            --ticks;
        }
        nanosleep(&delay, NULL);
    }
    return is_fallback(ctx) ? -1 : 0;
}

int main(int argc, char **argv) {
    const char *socket_path = argc > 1 ? argv[1] : "/tmp/anland/display_daemon.sock";
    int wait_seconds = argc > 2 ? atoi(argv[2]) : 15;
    display_ctx *ctx = NULL;
    uint32_t width = 0, height = 0, format = 0, refresh = 0;

    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);

    printf("[anland-probe] connecting daemon: %s\n", socket_path);
    if (connect_to_deamon(&ctx, socket_path) < 0 || ctx == NULL) {
        fprintf(stderr, "[anland-probe] daemon connection failed: %s\n", strerror(errno));
        return 2;
    }

    set_fallback_callback(ctx, on_fallback, NULL);
    if (get_screen_info(ctx, &width, &height, &format, &refresh) < 0) {
        fprintf(stderr, "[anland-probe] screen-info request failed\n");
        disconnect(ctx);
        return 3;
    }

    printf("[anland-probe] screen=%ux%u format=%u refresh=%u mHz\n",
           width, height, format, refresh);

    if (wait_for_consumer(ctx, wait_seconds) < 0) {
        fprintf(stderr,
                "[anland-probe] no display consumer after %d s; open the Anland Termux Activity and retry\n",
                wait_seconds);
        disconnect(ctx);
        return 4;
    }

    printf("[anland-probe] input monitor active; Ctrl+C exits\n");
    while (running) {
        if (is_fallback(ctx)) {
            if (wait_for_consumer(ctx, 0) < 0) {
                continue;
            }
        }

        struct InputEvent event;
        memset(&event, 0, sizeof(event));
        int result = poll_input_event(ctx, &event, 250);
        if (result < 0) {
            continue;
        }
        if (result == 0) {
            continue;
        }
        printf("[anland-probe] input type=%u (%s)\n",
               event.type, input_type_name(event.type));
        fflush(stdout);
    }

    disconnect(ctx);
    return 0;
}
