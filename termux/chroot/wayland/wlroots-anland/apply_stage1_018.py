#!/usr/bin/env python3
"""Install the Anland backend skeleton against the real wlroots 0.18.2 ABI."""

from __future__ import annotations

import argparse
from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if text.count(old) != 1:
        raise RuntimeError(f"expected exactly one anchor in {path}: {old!r}")
    path.write_text(text.replace(old, new, 1))


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


PUBLIC_HEADER = r'''#ifndef WLR_BACKEND_ANLAND_H
#define WLR_BACKEND_ANLAND_H

#include <stdbool.h>
#include <wayland-server-core.h>
#include <wlr/backend.h>
#include <wlr/types/wlr_output.h>

struct wlr_backend *wlr_anland_backend_create(struct wl_display *display);
bool wlr_backend_is_anland(struct wlr_backend *backend);
bool wlr_output_is_anland(struct wlr_output *output);

#endif
'''

INTERNAL_HEADER = r'''#ifndef BACKEND_ANLAND_H
#define BACKEND_ANLAND_H

#include <stdbool.h>
#include <stdint.h>
#include <wayland-server-core.h>
#include <wlr/backend.h>
#include <wlr/types/wlr_output.h>

#include "vendor/display_producer.h"

struct wlr_anland_backend {
    struct wlr_backend backend;
    struct wl_display *display_server;
    struct wl_event_loop *event_loop;
    struct wl_listener display_destroy;
    struct wl_list outputs;
    struct wl_event_source *reconnect_timer;
    display_ctx *display;
    char *socket_path;
    uint32_t width;
    uint32_t height;
    uint32_t format;
    uint32_t refresh;
    bool started;
    bool consumer_ready;
};

struct wlr_anland_output {
    struct wlr_output wlr_output;
    struct wlr_anland_backend *backend;
    struct wl_list link;
    struct wl_event_source *frame_timer;
    int frame_delay_ms;
};

struct wlr_anland_backend *anland_backend_from_backend(struct wlr_backend *backend);
struct wlr_output *anland_backend_add_output(struct wlr_anland_backend *backend);
void anland_output_consumer_state(struct wlr_anland_output *output, bool ready);

#endif
'''

BACKEND_C = r'''#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include <wlr/backend/anland.h>
#include <wlr/backend/interface.h>
#include <wlr/util/log.h>

#include "backend/anland.h"

#define DEFAULT_SOCKET_PATH "/tmp/anland/display_daemon.sock"
#define RECONNECT_INTERVAL_MS 200

struct wlr_anland_backend *anland_backend_from_backend(struct wlr_backend *wlr_backend) {
    assert(wlr_backend_is_anland(wlr_backend));
    return (struct wlr_anland_backend *)wlr_backend;
}

static void publish_consumer_state(struct wlr_anland_backend *backend, bool ready) {
    if (backend->consumer_ready == ready) {
        return;
    }
    backend->consumer_ready = ready;
    struct wlr_anland_output *output;
    wl_list_for_each(output, &backend->outputs, link) {
        anland_output_consumer_state(output, ready);
    }
    wlr_log(WLR_INFO, "Anland Android consumer is %s", ready ? "ready" : "detached");
}

static int reconnect_timer(void *data) {
    struct wlr_anland_backend *backend = data;
    if (backend->display == NULL) {
        return 0;
    }
    if (is_fallback(backend->display)) {
        if (try_exit_fallback(backend->display) == 0 && !is_fallback(backend->display)) {
            publish_consumer_state(backend, true);
        } else {
            publish_consumer_state(backend, false);
        }
    } else {
        publish_consumer_state(backend, true);
    }
    wl_event_source_timer_update(backend->reconnect_timer, RECONNECT_INTERVAL_MS);
    return 0;
}

static void handle_fallback(void *data) {
    struct wlr_anland_backend *backend = data;
    publish_consumer_state(backend, false);
    if (backend->reconnect_timer != NULL) {
        wl_event_source_timer_update(backend->reconnect_timer, 1);
    }
}

static bool backend_start(struct wlr_backend *wlr_backend) {
    struct wlr_anland_backend *backend = anland_backend_from_backend(wlr_backend);
    wlr_log(WLR_INFO, "Starting Anland backend on %s (%ux%u @ %.3f Hz)",
        backend->socket_path, backend->width, backend->height,
        backend->refresh / 1000.0);

    struct wlr_anland_output *output;
    wl_list_for_each(output, &backend->outputs, link) {
        wlr_output_update_enabled(&output->wlr_output, true);
        wl_signal_emit_mutable(&backend->backend.events.new_output,
            &output->wlr_output);
    }

    backend->started = true;
    wl_event_source_timer_update(backend->reconnect_timer, 1);
    return true;
}

static void backend_destroy(struct wlr_backend *wlr_backend) {
    if (wlr_backend == NULL) {
        return;
    }
    struct wlr_anland_backend *backend = anland_backend_from_backend(wlr_backend);
    wl_list_remove(&backend->display_destroy.link);

    struct wlr_anland_output *output, *tmp;
    wl_list_for_each_safe(output, tmp, &backend->outputs, link) {
        wlr_output_destroy(&output->wlr_output);
    }

    if (backend->reconnect_timer != NULL) {
        wl_event_source_remove(backend->reconnect_timer);
    }
    if (backend->display != NULL) {
        disconnect(backend->display);
    }
    wlr_backend_finish(wlr_backend);
    free(backend->socket_path);
    free(backend);
}

static uint32_t get_buffer_caps(struct wlr_backend *wlr_backend) {
    (void)wlr_backend;
    return WLR_BUFFER_CAP_DATA_PTR | WLR_BUFFER_CAP_DMABUF | WLR_BUFFER_CAP_SHM;
}

static const struct wlr_backend_impl backend_impl = {
    .start = backend_start,
    .destroy = backend_destroy,
    .get_buffer_caps = get_buffer_caps,
};

static void handle_display_destroy(struct wl_listener *listener, void *data) {
    (void)data;
    struct wlr_anland_backend *backend =
        wl_container_of(listener, backend, display_destroy);
    backend_destroy(&backend->backend);
}

struct wlr_backend *wlr_anland_backend_create(struct wl_display *display) {
    const char *socket_path = getenv("ANLAND_SOCKET");
    if (socket_path == NULL || socket_path[0] == '\0') {
        socket_path = DEFAULT_SOCKET_PATH;
    }

    struct wlr_anland_backend *backend = calloc(1, sizeof(*backend));
    if (backend == NULL) {
        wlr_log_errno(WLR_ERROR, "Failed to allocate Anland backend");
        return NULL;
    }

    wlr_backend_init(&backend->backend, &backend_impl);
    backend->display_server = display;
    backend->event_loop = wl_display_get_event_loop(display);
    wl_list_init(&backend->outputs);
    backend->socket_path = strdup(socket_path);
    if (backend->socket_path == NULL) {
        free(backend);
        return NULL;
    }

    if (connect_to_deamon(&backend->display, backend->socket_path) < 0) {
        wlr_log(WLR_ERROR, "Failed to connect to Anland daemon at %s", backend->socket_path);
        free(backend->socket_path);
        free(backend);
        return NULL;
    }

    if (get_screen_info(backend->display, &backend->width, &backend->height,
            &backend->format, &backend->refresh) < 0 ||
            backend->width == 0 || backend->height == 0) {
        wlr_log(WLR_ERROR, "Anland daemon returned invalid screen metadata");
        disconnect(backend->display);
        free(backend->socket_path);
        free(backend);
        return NULL;
    }

    set_fallback_callback(backend->display, handle_fallback, backend);
    backend->reconnect_timer = wl_event_loop_add_timer(backend->event_loop,
        reconnect_timer, backend);
    if (backend->reconnect_timer == NULL) {
        disconnect(backend->display);
        free(backend->socket_path);
        free(backend);
        return NULL;
    }

    backend->display_destroy.notify = handle_display_destroy;
    wl_display_add_destroy_listener(display, &backend->display_destroy);

    if (anland_backend_add_output(backend) == NULL) {
        backend_destroy(&backend->backend);
        return NULL;
    }

    wlr_log(WLR_INFO, "Created Anland backend: %ux%u format=0x%x refresh=%u mHz",
        backend->width, backend->height, backend->format, backend->refresh);
    return &backend->backend;
}

bool wlr_backend_is_anland(struct wlr_backend *backend) {
    return backend != NULL && backend->impl == &backend_impl;
}
'''

OUTPUT_C = r'''#include <assert.h>
#include <inttypes.h>
#include <stdlib.h>

#include <wlr/backend/anland.h>
#include <wlr/interfaces/wlr_output.h>
#include <wlr/util/log.h>

#include "backend/anland.h"

static const uint32_t SUPPORTED_OUTPUT_STATE =
    WLR_OUTPUT_STATE_BACKEND_OPTIONAL |
    WLR_OUTPUT_STATE_MODE;

static struct wlr_anland_output *anland_output_from_output(struct wlr_output *wlr_output) {
    assert(wlr_output_is_anland(wlr_output));
    return (struct wlr_anland_output *)wlr_output;
}

static bool output_test(struct wlr_output *wlr_output,
        const struct wlr_output_state *state) {
    (void)wlr_output;
    uint32_t unsupported = state->committed & ~SUPPORTED_OUTPUT_STATE;
    if (unsupported != 0) {
        wlr_log(WLR_DEBUG,
            "Anland stage1 rejects unsupported output state fields: 0x%"PRIx32,
            unsupported);
        return false;
    }
    if (state->committed & WLR_OUTPUT_STATE_MODE) {
        assert(state->mode_type == WLR_OUTPUT_STATE_MODE_CUSTOM);
    }
    return true;
}

static bool output_commit(struct wlr_output *wlr_output,
        const struct wlr_output_state *state) {
    return output_test(wlr_output, state);
}

static void output_destroy(struct wlr_output *wlr_output) {
    struct wlr_anland_output *output = anland_output_from_output(wlr_output);
    wl_list_remove(&output->link);
    if (output->frame_timer != NULL) {
        wl_event_source_remove(output->frame_timer);
    }
    free(output);
}

static const struct wlr_output_impl output_impl = {
    .destroy = output_destroy,
    .commit = output_commit,
};

bool wlr_output_is_anland(struct wlr_output *output) {
    return output != NULL && output->impl == &output_impl;
}

static int signal_frame(void *data) {
    struct wlr_anland_output *output = data;
    if (output->backend->consumer_ready) {
        wlr_output_send_frame(&output->wlr_output);
    }
    return 0;
}

void anland_output_consumer_state(struct wlr_anland_output *output, bool ready) {
    if (ready && output->frame_timer != NULL) {
        wl_event_source_timer_update(output->frame_timer, 1);
    }
}

struct wlr_output *anland_backend_add_output(struct wlr_anland_backend *backend) {
    struct wlr_anland_output *output = calloc(1, sizeof(*output));
    if (output == NULL) {
        return NULL;
    }
    output->backend = backend;

    wlr_output_init(&output->wlr_output, &backend->backend, &output_impl,
        backend->display_server);
    wlr_output_update_custom_mode(&output->wlr_output,
        (int32_t)backend->width, (int32_t)backend->height,
        backend->refresh > INT32_MAX ? 0 : (int32_t)backend->refresh);
    wlr_output_set_name(&output->wlr_output, "ANLAND-1");
    wlr_output_set_description(&output->wlr_output,
        "Anland Android display (wlroots 0.18 backend)");

    int refresh_mhz = backend->refresh > 0 ? (int)backend->refresh : 60000;
    output->frame_delay_ms = 1000000 / refresh_mhz;
    if (output->frame_delay_ms < 1) output->frame_delay_ms = 1;
    output->frame_timer = wl_event_loop_add_timer(backend->event_loop,
        signal_frame, output);
    if (output->frame_timer == NULL) {
        free(output);
        return NULL;
    }

    wl_list_insert(&backend->outputs, &output->link);
    if (backend->started) {
        wlr_output_update_enabled(&output->wlr_output, true);
        wl_signal_emit_mutable(&backend->backend.events.new_output,
            &output->wlr_output);
    }
    return &output->wlr_output;
}
'''

MESON = r'''wlr_files += files(
    'backend.c',
    'output.c',
    'vendor/display_producer.c',
    'vendor/socket_utils.c',
)
'''


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    root = args.source.resolve()
    if "0.18.2" not in (root / "meson.build").read_text():
        raise RuntimeError("this overlay is pinned to wlroots 0.18.2")

    write(root / "include/wlr/backend/anland.h", PUBLIC_HEADER)
    write(root / "backend/anland.h", INTERNAL_HEADER)
    write(root / "backend/anland/backend.c", BACKEND_C)
    write(root / "backend/anland/output.c", OUTPUT_C)
    write(root / "backend/anland/meson.build", MESON)

    replace_once(root / "backend/meson.build",
        "subdir('headless')\n", "subdir('headless')\nsubdir('anland')\n")

    backend = root / "backend/backend.c"
    replace_once(backend,
        "#include <wlr/backend/headless.h>\n",
        "#include <wlr/backend/headless.h>\n#include <wlr/backend/anland.h>\n")

    headless_anchor = (
        "static struct wlr_backend *attempt_headless_backend(\n"
        "\t\tstruct wl_display *display) {"
    )
    helper = (
        "static struct wlr_backend *attempt_anland_backend(\n"
        "\t\tstruct wl_display *display) {\n"
        "\treturn wlr_anland_backend_create(display);\n"
        "}\n\n"
    )
    replace_once(backend, headless_anchor, helper + headless_anchor)
    replace_once(backend,
        "\t} else if (strcmp(name, \"headless\") == 0) {\n"
        "\t\tbackend = attempt_headless_backend(display);\n",
        "\t} else if (strcmp(name, \"headless\") == 0) {\n"
        "\t\tbackend = attempt_headless_backend(display);\n"
        "\t} else if (strcmp(name, \"anland\") == 0) {\n"
        "\t\tbackend = attempt_anland_backend(display);\n")

    print(f"wlroots 0.18.2 Anland base overlay applied to {root}")


if __name__ == "__main__":
    main()
