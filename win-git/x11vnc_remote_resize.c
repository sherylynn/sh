#define _GNU_SOURCE
#include <dlfcn.h>
#include <rfb/rfb.h>
#include <rfb/rfbproto.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#define NEWHOME_FLAGS_V1_MASK  0xffff0000U
#define NEWHOME_FLAGS_V1_MAGIC 0x4e480000U /* "NH" */
#define NEWHOME_FLAGS_V2_MASK  0xff000000U
#define NEWHOME_FLAGS_V2_MAGIC 0x4e000000U /* "N" + DPI12 + render12 */

typedef rfbScreenInfoPtr (*rfb_get_screen_fn)(int *, char **, int, int, int, int, int);
static rfbScreenInfoPtr hooked_screen;
static int newhome_set_desktop_size(int width, int height, int num_screens,
                                    struct rfbExtDesktopScreen *screens,
                                    struct _rfbClientRec *client);

static void *reinstall_hook_after_x11vnc_init(void *unused) {
    (void)unused;
    usleep(750000);
    if (hooked_screen != NULL) hooked_screen->setDesktopSizeHook = newhome_set_desktop_size;
    return NULL;
}

static int newhome_set_desktop_size(int width, int height, int num_screens,
                                    struct rfbExtDesktopScreen *screens,
                                    struct _rfbClientRec *client) {
    (void)client;
    if (width < 320 || height < 240 || width > 8192 || height > 8192 ||
        num_screens != 1 || screens == NULL || screens[0].x != 0 || screens[0].y != 0) {
        return rfbExtDesktopSize_InvalidScreenLayout;
    }

    uint32_t flags = screens[0].flags;
    unsigned int dpi = 0;
    unsigned int mode_code = 0;
    unsigned int render_milli = 0;
    if ((flags & NEWHOME_FLAGS_V1_MASK) == NEWHOME_FLAGS_V1_MAGIC) {
        dpi = flags & 0xffffU;
        if (dpi < 48U || dpi > 768U) dpi = 0;
    } else if ((flags & NEWHOME_FLAGS_V2_MASK) == NEWHOME_FLAGS_V2_MAGIC) {
        dpi = (flags >> 12) & 0xfffU;
        render_milli = flags & 0xfffU;
        if (dpi > 0U && dpi < 16U) {
            mode_code = dpi;
            dpi = 0;
        }
        if (dpi < 48U || dpi > 768U) dpi = 0;
        if (render_milli < 1U || render_milli > 4095U) render_milli = 0;
    }

    FILE *log = fopen("/tmp/x11vnc-remote-resize.log", "a");
    if (log != NULL) {
        fprintf(log, "time=%ld request=%dx%d flags=0x%08x dpi=%u mode=%s render=%.3f canvas=%ux%u pid=%ld\n",
                (long)time(NULL), width, height, flags, dpi,
                mode_code == 1U ? "local" : (mode_code == 2U ? "remote" : "resize"),
                render_milli / 1000.0,
                (unsigned int)((width * (uint64_t)render_milli + 500U) / 1000U),
                (unsigned int)((height * (uint64_t)render_milli + 500U) / 1000U),
                (long)getpid());
        fclose(log);
    }

    if (mode_code != 0U) return rfbExtDesktopSize_Success;

    pid_t pid = fork();
    if (pid < 0) return rfbExtDesktopSize_OutOfResources;
    if (pid == 0) {
        char geometry[32];
        char dpi_string[16];
        long max_fd = sysconf(_SC_OPEN_MAX);
        if (max_fd < 0 || max_fd > 65536) max_fd = 65536;
        setsid();
        unsetenv("LD_PRELOAD");
        unsetenv("LD_DEBUG");
        for (int fd = 3; fd < max_fd; ++fd) close(fd);

        snprintf(geometry, sizeof(geometry), "%dx%d", width, height);
        snprintf(dpi_string, sizeof(dpi_string), "%u", dpi);
        execl("/bin/bash", "bash",
              "/root/sh/win-git/noVNC_remote_profile.sh",
              geometry, dpi_string, (char *)NULL);
        _exit(127);
    }
    return rfbExtDesktopSize_Success;
}

rfbScreenInfoPtr rfbGetScreen(int *argc, char **argv, int width, int height,
                              int bits_per_sample, int samples_per_pixel,
                              int bytes_per_pixel) {
    static rfb_get_screen_fn real_rfb_get_screen;
    if (real_rfb_get_screen == NULL) {
        real_rfb_get_screen = (rfb_get_screen_fn)dlsym(RTLD_NEXT, "rfbGetScreen");
        if (real_rfb_get_screen == NULL) _exit(126);
    }
    rfbScreenInfoPtr screen = real_rfb_get_screen(
        argc, argv, width, height, bits_per_sample, samples_per_pixel, bytes_per_pixel);
    if (screen != NULL) {
        FILE *log = fopen("/tmp/x11vnc-remote-resize.log", "a");
        if (log != NULL) {
            fprintf(log, "time=%ld adapter=loaded framebuffer=%dx%d\n",
                    (long)time(NULL), width, height);
            fclose(log);
        }
        pthread_t thread;
        hooked_screen = screen;
        screen->setDesktopSizeHook = newhome_set_desktop_size;
        if (pthread_create(&thread, NULL, reinstall_hook_after_x11vnc_init, NULL) == 0) {
            pthread_detach(thread);
        }
    }
    return screen;
}
