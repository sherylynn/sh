#!/usr/bin/env python3
"""Add Anland input devices to the stage-1 wlroots backend tree."""

from pathlib import Path
import argparse


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if text.count(old) != 1:
        raise RuntimeError(f"expected one anchor in {path}: {old!r}")
    path.write_text(text.replace(old, new, 1))


INPUT_C = r'''#include <stdint.h>
#include <stdlib.h>
#include <time.h>

#include <wayland-server-protocol.h>
#include <wlr/interfaces/wlr_keyboard.h>
#include <wlr/interfaces/wlr_pointer.h>
#include <wlr/interfaces/wlr_touch.h>
#include <wlr/util/log.h>

#include "backend/anland.h"

static const struct wlr_pointer_impl pointer_impl = { .name = "anland-pointer" };
static const struct wlr_keyboard_impl keyboard_impl = { .name = "anland-keyboard" };
static const struct wlr_touch_impl touch_impl = { .name = "anland-touch" };

static uint32_t now_msec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint32_t)((uint64_t)ts.tv_sec * 1000u + (uint64_t)ts.tv_nsec / 1000000u);
}

static double norm(float value, uint32_t extent) {
    if (extent == 0) return 0.0;
    double result = (double)value / (double)extent;
    if (result < 0.0) return 0.0;
    if (result > 1.0) return 1.0;
    return result;
}

static void emit_pointer_motion(struct wlr_anland_backend *backend,
        const struct InputEvent *ev) {
    uint32_t time = now_msec();
    struct wlr_pointer_motion_absolute_event abs = {
        .pointer = &backend->pointer,
        .time_msec = time,
        .x = norm(ev->pointer_motion.x, backend->width),
        .y = norm(ev->pointer_motion.y, backend->height),
    };
    wl_signal_emit_mutable(&backend->pointer.events.motion_absolute, &abs);

    if (ev->pointer_motion.dx != 0.0f || ev->pointer_motion.dy != 0.0f) {
        struct wlr_pointer_motion_event rel = {
            .pointer = &backend->pointer,
            .time_msec = time,
            .delta_x = ev->pointer_motion.dx,
            .delta_y = ev->pointer_motion.dy,
            .unaccel_dx = ev->pointer_motion.dx,
            .unaccel_dy = ev->pointer_motion.dy,
        };
        wl_signal_emit_mutable(&backend->pointer.events.motion, &rel);
    }
    wl_signal_emit_mutable(&backend->pointer.events.frame, &backend->pointer);
}

static void emit_pointer_button(struct wlr_anland_backend *backend,
        const struct InputEvent *ev) {
    struct wlr_pointer_button_event event = {
        .pointer = &backend->pointer,
        .time_msec = now_msec(),
        .button = ev->pointer_button.button,
        .state = ev->pointer_button.pressed ?
            WL_POINTER_BUTTON_STATE_PRESSED : WL_POINTER_BUTTON_STATE_RELEASED,
    };
    wl_signal_emit_mutable(&backend->pointer.events.button, &event);
    wl_signal_emit_mutable(&backend->pointer.events.frame, &backend->pointer);
}

static void emit_pointer_axis(struct wlr_anland_backend *backend,
        const struct InputEvent *ev) {
    struct wlr_pointer_axis_event event = {
        .pointer = &backend->pointer,
        .time_msec = now_msec(),
        .source = WL_POINTER_AXIS_SOURCE_WHEEL,
        .orientation = ev->pointer_axis.axis,
        .delta = ev->pointer_axis.value,
        .delta_discrete = ev->pointer_axis.discrete * WLR_POINTER_AXIS_DISCRETE_STEP,
        .relative_direction = WL_POINTER_AXIS_RELATIVE_DIRECTION_IDENTICAL,
    };
    wl_signal_emit_mutable(&backend->pointer.events.axis, &event);
    wl_signal_emit_mutable(&backend->pointer.events.frame, &backend->pointer);
}

static void emit_key(struct wlr_anland_backend *backend,
        const struct InputEvent *ev) {
    struct wlr_keyboard_key_event event = {
        .time_msec = now_msec(),
        .keycode = (uint32_t)ev->key.keycode,
        .update_state = true,
        .state = ev->key.action == INPUT_ACTION_DOWN ?
            WL_KEYBOARD_KEY_STATE_PRESSED : WL_KEYBOARD_KEY_STATE_RELEASED,
    };
    wlr_keyboard_notify_key(&backend->keyboard, &event);
}

static void emit_touch(struct wlr_anland_backend *backend,
        const struct InputEvent *ev) {
    uint32_t time = now_msec();
    switch (ev->touch.action) {
    case INPUT_ACTION_DOWN: {
        struct wlr_touch_down_event event = {
            .touch = &backend->touch,
            .time_msec = time,
            .touch_id = ev->touch.pointer_id,
            .x = norm(ev->touch.x, backend->width),
            .y = norm(ev->touch.y, backend->height),
        };
        wl_signal_emit_mutable(&backend->touch.events.down, &event);
        break;
    }
    case INPUT_ACTION_UP: {
        struct wlr_touch_up_event event = {
            .touch = &backend->touch,
            .time_msec = time,
            .touch_id = ev->touch.pointer_id,
        };
        wl_signal_emit_mutable(&backend->touch.events.up, &event);
        break;
    }
    case INPUT_ACTION_MOVE: {
        struct wlr_touch_motion_event event = {
            .touch = &backend->touch,
            .time_msec = time,
            .touch_id = ev->touch.pointer_id,
            .x = norm(ev->touch.x, backend->width),
            .y = norm(ev->touch.y, backend->height),
        };
        wl_signal_emit_mutable(&backend->touch.events.motion, &event);
        break;
    }
    default:
        break;
    }
}

static void process_input(struct wlr_anland_backend *backend,
        const struct InputEvent *ev) {
    switch (ev->type) {
    case INPUT_TYPE_POINTER_MOTION: emit_pointer_motion(backend, ev); break;
    case INPUT_TYPE_POINTER_BUTTON: emit_pointer_button(backend, ev); break;
    case INPUT_TYPE_POINTER_AXIS: emit_pointer_axis(backend, ev); break;
    case INPUT_TYPE_KEY: emit_key(backend, ev); break;
    case INPUT_TYPE_TOUCH: emit_touch(backend, ev); break;
    case INPUT_TYPE_TOUCH_FRAME:
        wl_signal_emit_mutable(&backend->touch.events.frame, NULL);
        break;
    default:
        break;
    }
}

static int input_fd_handler(int fd, uint32_t mask, void *data) {
    (void)fd;
    struct wlr_anland_backend *backend = data;
    if (mask & (WL_EVENT_HANGUP | WL_EVENT_ERROR)) {
        anland_input_detach(backend);
        return 0;
    }
    struct InputEvent ev;
    int result;
    while ((result = poll_input_event(backend->display, &ev, 0)) > 0) {
        process_input(backend, &ev);
    }
    if (result < 0) {
        anland_input_detach(backend);
    }
    return 0;
}

bool anland_input_init(struct wlr_anland_backend *backend) {
    wlr_pointer_init(&backend->pointer, &pointer_impl, "Anland pointer");
    backend->pointer.output_name = strdup("ANLAND-1");
    wlr_keyboard_init(&backend->keyboard, &keyboard_impl, "Anland keyboard");
    wlr_touch_init(&backend->touch, &touch_impl, "Anland touch");
    backend->touch.output_name = strdup("ANLAND-1");
    return backend->pointer.output_name != NULL && backend->touch.output_name != NULL;
}

void anland_input_publish(struct wlr_anland_backend *backend) {
    if (backend->inputs_published) return;
    backend->inputs_published = true;
    wl_signal_emit_mutable(&backend->backend.events.new_input, &backend->pointer.base);
    wl_signal_emit_mutable(&backend->backend.events.new_input, &backend->keyboard.base);
    wl_signal_emit_mutable(&backend->backend.events.new_input, &backend->touch.base);
}

void anland_input_attach(struct wlr_anland_backend *backend) {
    if (backend->input_source != NULL || backend->display == NULL ||
            is_fallback(backend->display)) return;
    int fd = get_data_fd(backend->display);
    if (fd < 0) return;
    backend->input_source = wl_event_loop_add_fd(backend->event_loop, fd,
        WL_EVENT_READABLE | WL_EVENT_HANGUP | WL_EVENT_ERROR,
        input_fd_handler, backend);
    if (backend->input_source == NULL) {
        wlr_log(WLR_ERROR, "Failed to attach Anland input fd");
    }
}

void anland_input_detach(struct wlr_anland_backend *backend) {
    if (backend->input_source != NULL) {
        wl_event_source_remove(backend->input_source);
        backend->input_source = NULL;
    }
}

void anland_input_finish(struct wlr_anland_backend *backend) {
    anland_input_detach(backend);
    wlr_pointer_finish(&backend->pointer);
    wlr_keyboard_finish(&backend->keyboard);
    wlr_touch_finish(&backend->touch);
}
'''


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("source", type=Path)
    args = p.parse_args()
    root = args.source.resolve()
    header = root / "backend/anland.h"
    backend = root / "backend/anland/backend.c"
    meson = root / "backend/anland/meson.build"
    if not header.exists() or not backend.exists():
        raise RuntimeError("apply stage1 overlay before stage2")

    replace_once(
        header,
        '#include <wlr/types/wlr_output.h>\n',
        '#include <wlr/types/wlr_output.h>\n'
        '#include <wlr/interfaces/wlr_pointer.h>\n'
        '#include <wlr/interfaces/wlr_keyboard.h>\n'
        '#include <wlr/interfaces/wlr_touch.h>\n',
    )
    replace_once(
        header,
        '    struct wl_event_source *reconnect_timer;\n',
        '    struct wl_event_source *reconnect_timer;\n'
        '    struct wl_event_source *input_source;\n'
        '    struct wlr_pointer pointer;\n'
        '    struct wlr_keyboard keyboard;\n'
        '    struct wlr_touch touch;\n'
        '    bool inputs_published;\n',
    )
    replace_once(
        header,
        'void anland_output_consumer_state(struct wlr_anland_output *output, bool ready);\n',
        'void anland_output_consumer_state(struct wlr_anland_output *output, bool ready);\n'
        'bool anland_input_init(struct wlr_anland_backend *backend);\n'
        'void anland_input_publish(struct wlr_anland_backend *backend);\n'
        'void anland_input_attach(struct wlr_anland_backend *backend);\n'
        'void anland_input_detach(struct wlr_anland_backend *backend);\n'
        'void anland_input_finish(struct wlr_anland_backend *backend);\n',
    )

    write_path = root / "backend/anland/input.c"
    write_path.write_text(INPUT_C)
    replace_once(meson, "    'output.c',\n", "    'output.c',\n    'input.c',\n")

    replace_once(
        backend,
        '    backend->consumer_ready = ready;\n',
        '    backend->consumer_ready = ready;\n'
        '    if (ready) {\n'
        '        anland_input_attach(backend);\n'
        '    } else {\n'
        '        anland_input_detach(backend);\n'
        '    }\n',
    )
    replace_once(
        backend,
        '    backend->started = true;\n',
        '    backend->started = true;\n'
        '    anland_input_publish(backend);\n',
    )
    replace_once(
        backend,
        '    if (backend->reconnect_timer != NULL) {\n        wl_event_source_remove(backend->reconnect_timer);\n    }\n',
        '    anland_input_finish(backend);\n'
        '    if (backend->reconnect_timer != NULL) {\n        wl_event_source_remove(backend->reconnect_timer);\n    }\n',
    )
    replace_once(
        backend,
        '    set_fallback_callback(backend->display, handle_fallback, backend);\n',
        '    if (!anland_input_init(backend)) {\n'
        '        wlr_log(WLR_ERROR, "Failed to initialize Anland input devices");\n'
        '        disconnect(backend->display);\n'
        '        free(backend->socket_path);\n'
        '        free(backend);\n'
        '        return NULL;\n'
        '    }\n'
        '    set_fallback_callback(backend->display, handle_fallback, backend);\n',
    )

    print(f"stage2 Anland input overlay applied to {root}")


if __name__ == "__main__":
    main()
