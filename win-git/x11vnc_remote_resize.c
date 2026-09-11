#define _GNU_SOURCE
#include <dlfcn.h>
#include <rfb/rfb.h>
#include <rfb/rfbproto.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define NEWHOME_FLAGS_MASK  0xffff0000U
#define NEWHOME_FLAGS_MAGIC 0x4e480000U /* "NH" */

typedef struct _XDisplay Display;
typedef unsigned long Atom;
typedef unsigned long Window;
typedef unsigned long Time;

#define X11_NONE       0UL
#define X11_XA_PRIMARY 1UL
#define X11_XA_STRING  31UL

typedef rfbScreenInfoPtr (*rfb_get_screen_fn)(int *, char **, int, int, int, int, int);
typedef Atom (*x_intern_atom_fn)(Display *, const char *, int);
typedef int (*x_convert_selection_fn)(Display *, Atom, Atom, Atom, Window, Time);
typedef int (*x_change_property_fn)(Display *, Window, Atom, Atom, int, int,
                                    const unsigned char *, int);

static rfbScreenInfoPtr hooked_screen;
static int newhome_set_desktop_size(int width, int height, int num_screens,
                                    struct rfbExtDesktopScreen *screens,
                                    struct _rfbClientRec *client);

static void log_clipboard_utf8(const char *message) {
    FILE *log = fopen("/tmp/x11vnc-clipboard-utf8.log", "a");
    if (log != NULL) {
        fprintf(log, "time=%ld %s pid=%ld\n",
                (long)time(NULL), message, (long)getpid());
        fclose(log);
    }
}

static Atom intern_atom(Display *display, const char *name) {
    static x_intern_atom_fn real_x_intern_atom;
    if (display == NULL) return X11_NONE;
    if (real_x_intern_atom == NULL) {
        real_x_intern_atom = (x_intern_atom_fn)dlsym(RTLD_NEXT, "XInternAtom");
        if (real_x_intern_atom == NULL) _exit(126);
    }
    return real_x_intern_atom(display, name, 0);
}

static Atom utf8_atom(Display *display) {
    return intern_atom(display, "UTF8_STRING");
}

static Atom clipboard_atom_for(Display *display) {
    return intern_atom(display, "CLIPBOARD");
}

/*
 * x11vnc still asks X11 applications for XA_STRING. That predates Unicode and
 * makes Chinese/CJK text lossy before it ever reaches noVNC. Since this shared
 * object is already LD_PRELOADed into x11vnc for remote-resize support, upgrade
 * only PRIMARY/CLIPBOARD conversions to UTF8_STRING here.
 */
int XConvertSelection(Display *display, Atom selection, Atom target,
                      Atom property, Window requestor, Time time) {
    static x_convert_selection_fn real_x_convert_selection;
    if (real_x_convert_selection == NULL) {
        real_x_convert_selection = (x_convert_selection_fn)dlsym(RTLD_NEXT, "XConvertSelection");
        if (real_x_convert_selection == NULL) _exit(126);
    }

    if (target == X11_XA_STRING && display != NULL) {
        Atom clipboard = clipboard_atom_for(display);
        if (selection == X11_XA_PRIMARY ||
            (clipboard != X11_NONE && selection == clipboard)) {
            Atom utf8 = utf8_atom(display);
            if (utf8 != X11_NONE) {
                target = utf8;
                log_clipboard_utf8("request-target=UTF8_STRING");
            }
        }
    }

    return real_x_convert_selection(display, selection, target,
                                    property, requestor, time);
}

/*
 * In the opposite direction x11vnc owns the X11 selection after receiving an
 * RFB ClientCutText message, but advertises only TARGETS + XA_STRING. Modern
 * Linux applications therefore choose the legacy target and interpret the raw
 * UTF-8 bytes incorrectly. Add UTF8_STRING to that exact TARGETS response;
 * x11vnc already returns the original bytes using the request target as the
 * property type, so UTF-8-aware applications then receive correct text.
 */
int XChangeProperty(Display *display, Window window, Atom property, Atom type,
                    int format, int mode, const unsigned char *data,
                    int nelements) {
    static x_change_property_fn real_x_change_property;
    if (real_x_change_property == NULL) {
        real_x_change_property = (x_change_property_fn)dlsym(RTLD_NEXT, "XChangeProperty");
        if (real_x_change_property == NULL) _exit(126);
    }

    if (display != NULL && data != NULL && format == 32 && nelements == 2) {
        Atom targets_atom = intern_atom(display, "TARGETS");
        const Atom *targets = (const Atom *)data;
        if (targets_atom != X11_NONE && type == targets_atom &&
            targets[0] == targets_atom && targets[1] == X11_XA_STRING) {
            Atom utf8 = utf8_atom(display);
            if (utf8 != X11_NONE && utf8 != X11_XA_STRING) {
                Atom upgraded[3];
                upgraded[0] = targets_atom;
                upgraded[1] = X11_XA_STRING;
                upgraded[2] = utf8;
                log_clipboard_utf8("advertise-target=UTF8_STRING");
                return real_x_change_property(display, window, property, type,
                                              format, mode,
                                              (const unsigned char *)upgraded, 3);
            }
        }
    }

    return real_x_change_property(display, window, property, type,
                                  format, mode, data, nelements);
}

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
    if ((flags & NEWHOME_FLAGS_MASK) == NEWHOME_FLAGS_MAGIC) {
        dpi = flags & 0xffffU;
        if (dpi < 48U || dpi > 768U) dpi = 0;
    }

    FILE *log = fopen("/tmp/x11vnc-remote-resize.log", "a");
    if (log != NULL) {
        fprintf(log, "time=%ld request=%dx%d flags=0x%08x dpi=%u pid=%ld\n",
                (long)time(NULL), width, height, flags, dpi, (long)getpid());
        fclose(log);
    }

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
