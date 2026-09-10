#define _GNU_SOURCE
#include <dlfcn.h>
#include <rfb/rfb.h>
#include <rfb/rfbproto.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

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
    FILE *log = fopen("/tmp/x11vnc-remote-resize.log", "a");
    if (log != NULL) {
        fprintf(log, "time=%ld request=%dx%d pid=%ld\n",
                (long)time(NULL), width, height, (long)getpid());
        fclose(log);
    }
    pid_t pid = fork();
    if (pid < 0) return rfbExtDesktopSize_OutOfResources;
    if (pid == 0) {
        char geometry[32];
        long max_fd = sysconf(_SC_OPEN_MAX);
        if (max_fd < 0 || max_fd > 65536) max_fd = 65536;
        setsid();
        unsetenv("LD_PRELOAD");
        unsetenv("LD_DEBUG");
        for (int fd = 3; fd < max_fd; ++fd) close(fd);
        snprintf(geometry, sizeof(geometry), "%dx%d", width, height);
        execl("/root/sh/win-git/xfce4-scaling.sh", "xfce4-scaling.sh",
              "--queue-remote-resize", geometry, (char *)NULL);
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
