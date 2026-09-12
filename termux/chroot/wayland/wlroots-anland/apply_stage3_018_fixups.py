#!/usr/bin/env python3
"""Final wlroots-0.18 ABI fixups for the Stage 3 Anland backend."""

from __future__ import annotations

import argparse
from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if text.count(old) != 1:
        raise RuntimeError(f"expected one stage3/0.18 anchor in {path}: {old!r}")
    path.write_text(text.replace(old, new, 1))


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("source", type=Path)
    args = p.parse_args()
    root = args.source.resolve()
    header = root / "backend/anland.h"
    backend = root / "backend/anland/backend.c"
    output = root / "backend/anland/output.c"
    presenter = root / "backend/anland/presenter.c"
    meson = root / "backend/anland/meson.build"
    wayland_output = root / "backend/wayland/output.c"

    replace_once(header,
        '    uint32_t refresh;\n',
        '    uint32_t refresh;\n    int drm_fd;\n')

    replace_once(backend,
        '#include <assert.h>\n',
        '#include <assert.h>\n#include <fcntl.h>\n#include <unistd.h>\n')

    get_caps = '''static uint32_t get_buffer_caps(struct wlr_backend *wlr_backend) {
    (void)wlr_backend;
    return WLR_BUFFER_CAP_DMABUF;
}
'''
    replacement = '''static int get_drm_fd(struct wlr_backend *wlr_backend) {
    struct wlr_anland_backend *backend = anland_backend_from_backend(wlr_backend);
    return backend->drm_fd;
}

static uint32_t get_buffer_caps(struct wlr_backend *wlr_backend) {
    (void)wlr_backend;
    return WLR_BUFFER_CAP_DMABUF;
}
'''
    replace_once(backend, get_caps, replacement)
    replace_once(backend,
        '    .destroy = backend_destroy,\n    .get_buffer_caps = get_buffer_caps,\n',
        '    .destroy = backend_destroy,\n    .get_drm_fd = get_drm_fd,\n'
        '    .get_buffer_caps = get_buffer_caps,\n')

    replace_once(backend,
        '    if (backend->display != NULL) {\n        disconnect(backend->display);\n    }\n',
        '    if (backend->display != NULL) {\n        disconnect(backend->display);\n    }\n'
        '    if (backend->drm_fd >= 0) {\n        close(backend->drm_fd);\n        backend->drm_fd = -1;\n    }\n')

    replace_once(backend,
        '    wlr_backend_init(&backend->backend, &backend_impl);\n',
        '    wlr_backend_init(&backend->backend, &backend_impl);\n'
        '    backend->drm_fd = -1;\n'
        '    const char *drm_path = getenv("ANLAND_DRM_DEVICE");\n'
        '    if (drm_path == NULL || drm_path[0] == \'\\0\') {\n'
        '        drm_path = "/dev/dri/renderD128";\n'
        '    }\n'
        '    backend->drm_fd = open(drm_path, O_RDWR | O_CLOEXEC);\n'
        '    if (backend->drm_fd < 0) {\n'
        '        wlr_log_errno(WLR_ERROR, "Unable to open Anland render node %s", drm_path);\n'
        '        free(backend);\n'
        '        return NULL;\n'
        '    }\n'
        '    wlr_log(WLR_INFO, "Anland render node: %s fd=%d", drm_path, backend->drm_fd);\n')

    text = backend.read_text()
    text = text.replace(
        '        free(backend);\n        return NULL;\n',
        '        if (backend->drm_fd >= 0) close(backend->drm_fd);\n'
        '        free(backend);\n        return NULL;\n')
    backend.write_text(text)

    old_commit = '''    if (state->committed & WLR_OUTPUT_STATE_BUFFER) {
        if (!anland_presenter_blit(output->backend->presenter,
                output->backend, state->buffer)) {
            wlr_log(WLR_ERROR, "Anland GPU DMA-BUF presentation failed");
            return false;
        }
    }
    return true;
'''
    new_commit = '''    if (state->committed & WLR_OUTPUT_STATE_BUFFER) {
        if (!output->backend->consumer_ready || is_fallback(output->backend->display)) {
            /* Accept the modeset while Android is attaching. The ready edge
             * schedules a fresh frame, so no CPU fallback or stale buffer is used. */
            return true;
        }
        if (!anland_presenter_blit(output->backend->presenter,
                output->backend, state->buffer)) {
            wlr_log(WLR_ERROR, "Anland GPU DMA-BUF presentation failed");
            return false;
        }
        struct wlr_output_event_present present_event = {
            .commit_seq = wlr_output->commit_seq + 1,
            .presented = true,
        };
        wlr_output_send_present(wlr_output, &present_event);
    }
    return true;
'''
    replace_once(output, old_commit, new_commit)

    # Match Weston-Anland's lockstep: connection only wires the eventfd. The
    # first and all subsequent frames are requested by buffer-ready events.
    replace_once(output,
        '''void anland_output_consumer_state(struct wlr_anland_output *output, bool ready) {
    if (ready && output->frame_timer != NULL) {
        /* One bootstrap frame starts the Android buffer-ready cadence. */
        wl_event_source_timer_update(output->frame_timer, 1);
    }
}
''',
        '''void anland_output_consumer_state(struct wlr_anland_output *output, bool ready) {
    (void)output;
    (void)ready;
    /* presenter.c emits frames only after Android signals buffer-ready. */
}
''')

    replace_once(presenter,
        '#include <wlr/types/wlr_output.h>\n',
        '#include <wlr/interfaces/wlr_output.h>\n#include <wlr/types/wlr_output.h>\n')

    replace_once(output,
        '''    if (state->committed & WLR_OUTPUT_STATE_BUFFER) {
        if (state->buffer == NULL || !output->backend->consumer_ready ||
                is_fallback(output->backend->display)) {
            return false;
        }
    }
''',
        '''    if ((state->committed & WLR_OUTPUT_STATE_BUFFER) && state->buffer == NULL) {
        return false;
    }
''')

    replace_once(presenter,
        '    return trigger_refresh(backend->display) == 0;\n',
        '    int refresh_status = trigger_refresh(backend->display);\n'
        '    if (refresh_status == 0) {\n'
        '        static bool first_frame_logged = false;\n'
        '        if (!first_frame_logged) {\n'
        '            first_frame_logged = true;\n'
        '            wlr_log(WLR_INFO, "Anland first GPU DMA-BUF frame presented successfully");\n'
        '        }\n'
        '    }\n'
        '    return refresh_status == 0;\n')

    replace_once(meson,
        "wlr_files += files(\n",
        "wlr_deps += [dependency('egl'), dependency('glesv2')]\n\n"
        "wlr_files += files(\n")

    # kiosk-shell configures the real Android output size after the first xdg
    # handshake. A 1280x720 initial surface is rejected on portrait displays
    # before that configure can arrive; 1x1 is always valid and immediately
    # replaced by the compositor-provided size.
    replace_once(wayland_output,
        'wlr_output_state_set_custom_mode(&state, 1280, 720, 0);\n',
        'wlr_output_state_set_custom_mode(&state, 1, 1, 0);\n')

    print("stage3 wlroots 0.18 ABI/render-node/EGL fixups applied")


if __name__ == "__main__":
    main()
