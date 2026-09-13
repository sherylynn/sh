#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

struct nvnc;
struct nvnc_client;
struct nvnc_desktop_layout;
typedef bool (*nvnc_desktop_layout_fn)(
    struct nvnc_client *, const struct nvnc_desktop_layout *);

extern uint16_t nvnc_desktop_layout_get_width(
    const struct nvnc_desktop_layout *layout);
extern uint16_t nvnc_desktop_layout_get_height(
    const struct nvnc_desktop_layout *layout);

static bool newhome_anland_resize(
        struct nvnc_client *client, const struct nvnc_desktop_layout *layout) {
    (void)client;
    uint16_t width = nvnc_desktop_layout_get_width(layout);
    uint16_t height = nvnc_desktop_layout_get_height(layout);
    if (width < 320 || height < 240) {
        return false;
    }

    char resolution[32];
    snprintf(resolution, sizeof(resolution), "%ux%u", width, height);
    const char *configured_script = getenv("NEWHOME_ANLAND_RESIZE_SCRIPT");
    if (!configured_script || !*configured_script)
        configured_script = "/root/sh/termux/chroot/wayland/anland_remote_resize.sh";
    char script[512];
    snprintf(script, sizeof(script), "%s", configured_script);

    FILE *log = fopen("/tmp/wayvnc-anland-resize-hook.log", "a");
    if (log) {
        fprintf(log, "request=%s\n", resolution);
        fclose(log);
    }

    pid_t first = fork();
    if (first < 0) {
        return false;
    }
    if (first == 0) {
        pid_t worker = fork();
        if (worker < 0) {
            _exit(1);
        }
        if (worker > 0) {
            _exit(0);
        }
        setsid();
        /* Hook 仅能装载到 wayvnc；若让 /bin/bash 继承，动态链接器
         * 会因找不到 neatvnc 符号而在执行 resize 脚本前退出。 */
        unsetenv("LD_PRELOAD");
        long max_fd = sysconf(_SC_OPEN_MAX);
        if (max_fd < 0 || max_fd > 4096) {
            max_fd = 4096;
        }
        for (int fd = 0; fd < max_fd; ++fd) {
            close(fd);
        }
        int worker_log = open("/tmp/wayvnc-anland-resize-worker.log",
            O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (worker_log >= 0) {
            dup2(worker_log, STDOUT_FILENO);
            dup2(worker_log, STDERR_FILENO);
            if (worker_log > STDERR_FILENO)
                close(worker_log);
        }
        execl("/bin/bash", "bash", script, resolution, "--remote", (char *)NULL);
        _exit(127);
    }
    while (waitpid(first, NULL, 0) < 0 && errno == EINTR) {
    }
    /* 立即回复 RFB 客户端，实际重连由后台 worker 完成。 */
    return true;
}

void nvnc_set_desktop_layout_fn(struct nvnc *server,
        nvnc_desktop_layout_fn original) {
    (void)original;
    typedef void (*real_fn)(struct nvnc *, nvnc_desktop_layout_fn);
    real_fn real = (real_fn)dlsym(RTLD_NEXT, "nvnc_set_desktop_layout_fn");
    if (!real) {
        return;
    }
    real(server, newhome_anland_resize);
}
