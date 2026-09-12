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
    meson = root / "backend/anland/meson.build"

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

    old_init = '''    int32_t refresh = backend->refresh > INT32_MAX ? 0 : (int32_t)backend->refresh;
    struct wlr_output_state state;
    wlr_output_state_init(&state);
    wlr_output_state_set_custom_mode(&state,
        (int32_t)backend->width, (int32_t)backend->height, refresh);
    wlr_output_init(&output->wlr_output, &backend->backend, &output_impl,
        backend->event_loop, &state);
    wlr_output_state_finish(&state);
'''
    new_init = '''    int32_t refresh = backend->refresh > INT32_MAX ? 0 : (int32_t)backend->refresh;
    wlr_output_init(&output->wlr_output, &backend->backend, &output_impl,
        backend->display_server);
    wlr_output_update_custom_mode(&output->wlr_output,
        (int32_t)backend->width, (int32_t)backend->height, refresh);
'''
    replace_once(output, old_init, new_init)

    old_commit = '''    if (state->committed & WLR_OUTPUT_STATE_BUFFER) {
        if (!anland_presenter_blit(output->backend->presenter,
                output->backend, state->buffer)) {
            wlr_log(WLR_ERROR, "Anland GPU DMA-BUF presentation failed");
            return false;
        }
    }
    return true;
'''
    new_commit = '''    if (state->committed & WLR_OUTPUT_STATE_ENABLED) {
        wlr_output_update_enabled(wlr_output, state->enabled);
    }
    if (state->committed & WLR_OUTPUT_STATE_MODE) {
        wlr_output_update_custom_mode(wlr_output,
            state->custom_mode.width, state->custom_mode.height,
            state->custom_mode.refresh);
    }
    if (state->committed & WLR_OUTPUT_STATE_BUFFER) {
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

    # presenter.c calls EGL/GLES directly. Make these explicit wlroots library
    # dependencies instead of relying on renderer subdir side effects.
    replace_once(meson,
        "wlr_files += files(\n",
        "wlr_deps += [dependency('egl'), dependency('glesv2')]\n\n"
        "wlr_files += files(\n")

    print("stage3 wlroots 0.18 ABI/render-node/EGL fixups applied")


if __name__ == "__main__":
    main()
