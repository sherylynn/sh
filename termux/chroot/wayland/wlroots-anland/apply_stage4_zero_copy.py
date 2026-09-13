#!/usr/bin/env python3
"""Stage 4: render wlroots output directly into Anland consumer DMA-BUFs.

Pinned to Debian 13 wlroots 0.18.2. This removes the Stage3 fullscreen
EGL/GLES blit: Labwc's normal renderer receives the Android-selected Anland
DMA-BUF itself as its render target. The Anland transport remains the owner of
the original DMA-BUF FDs; Stage4 wrappers duplicate them for safe wlroots
lifetime management.
"""
from __future__ import annotations

import argparse
from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"expected exactly one anchor in {path}: {old!r}, got {count}")
    path.write_text(text.replace(old, new, 1))


def replace_between(path: Path, start: str, end: str, replacement: str) -> None:
    text = path.read_text()
    a = text.find(start)
    if a < 0:
        raise RuntimeError(f"start anchor not found in {path}: {start!r}")
    b = text.find(end, a)
    if b < 0:
        raise RuntimeError(f"end anchor not found in {path}: {end!r}")
    path.write_text(text[:a] + replacement + text[b:])


TEMPLATE_DIR = Path(__file__).resolve().parent / "templates"
BUFFER_C = (TEMPLATE_DIR / "stage4_buffer.c").read_text()
OUTPUT_C = (TEMPLATE_DIR / "stage4_output.c").read_text()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    root = args.source.resolve()
    if "0.18.2" not in (root / "meson.build").read_text():
        raise RuntimeError("Stage4 overlay is pinned to wlroots 0.18.2")

    header = root / "backend/anland.h"
    backend = root / "backend/anland/backend.c"
    output = root / "backend/anland/output.c"
    meson = root / "backend/anland/meson.build"
    output_iface = root / "include/wlr/interfaces/wlr_output.h"
    render = root / "types/output/render.c"
    wayland_output = root / "backend/wayland/output.c"

    # Generic wlroots hook: by default every backend still uses the existing
    # swapchain. Only Anland supplies an externally-owned render target.
    replace_once(output_iface,
        '''\tconst struct wlr_drm_format_set *(*get_primary_formats)(\n\t\tstruct wlr_output *output, uint32_t buffer_caps);\n''',
        '''\tconst struct wlr_drm_format_set *(*get_primary_formats)(\n\t\tstruct wlr_output *output, uint32_t buffer_caps);\n\t/** Optional externally-owned render target. Returned buffer must be locked. */\n\tstruct wlr_buffer *(*acquire_render_buffer)(struct wlr_output *output,\n\t\tconst struct wlr_output_state *state);\n''')

    # wlroots 0.18 still exposes buffer_age. External Anland targets aren't a
    # wlroots-owned swapchain, so report age=0 and force conservative repaint.
    replace_once(render,
        '''static struct wlr_buffer *output_acquire_empty_buffer(struct wlr_output *output,\n\t\tconst struct wlr_output_state *state) {\n''',
        '''static struct wlr_buffer *output_acquire_render_buffer(struct wlr_output *output,\n\t\tconst struct wlr_output_state *state, int *buffer_age) {\n\tif (output->impl->acquire_render_buffer != NULL) {\n\t\tif (buffer_age != NULL) {\n\t\t\t*buffer_age = 0;\n\t\t}\n\t\treturn output->impl->acquire_render_buffer(output, state);\n\t}\n\tif (!wlr_output_configure_primary_swapchain(output, state, &output->swapchain)) {\n\t\treturn NULL;\n\t}\n\treturn wlr_swapchain_acquire(output->swapchain, buffer_age);\n}\n\nstatic struct wlr_buffer *output_acquire_empty_buffer(struct wlr_output *output,\n\t\tconst struct wlr_output_state *state) {\n''')

    replace_once(render,
        '''\t// wlr_output_configure_primary_swapchain() function will call\n\t// wlr_output_test_state(), which can call us again. This is dangerous: we\n\t// risk infinite recursion. However, a buffer will always be supplied in\n\t// wlr_output_test_state(), which will prevent us from being called.\n\tif (!wlr_output_configure_primary_swapchain(output, state,\n\t\t\t&output->swapchain)) {\n\t\treturn NULL;\n\t}\n\n\tstruct wlr_buffer *buffer = wlr_swapchain_acquire(output->swapchain, NULL);\n''',
        '''\tstruct wlr_buffer *buffer = output_acquire_render_buffer(output, state, NULL);\n''')

    # Exact wlroots 0.18.2 ABI: fourth argument is a render timer. wlroots then
    # builds wlr_buffer_pass_options internally; Stage4 only replaces acquisition.
    replace_once(render,
        '''struct wlr_render_pass *wlr_output_begin_render_pass(struct wlr_output *output,\n\t\tstruct wlr_output_state *state, int *buffer_age, struct wlr_render_timer *timer) {\n\tif (!wlr_output_configure_primary_swapchain(output, state, &output->swapchain)) {\n\t\treturn NULL;\n\t}\n\n\tstruct wlr_buffer *buffer = wlr_swapchain_acquire(output->swapchain, buffer_age);\n''',
        '''struct wlr_render_pass *wlr_output_begin_render_pass(struct wlr_output *output,\n\t\tstruct wlr_output_state *state, int *buffer_age, struct wlr_render_timer *timer) {\n\tstruct wlr_buffer *buffer = output_acquire_render_buffer(output, state, buffer_age);\n''')

    # Extend generated Anland backend state after Stage2 has inserted input fields.
    replace_once(header,
        '#include <wlr/types/wlr_output.h>\n',
        '#include <wlr/types/wlr_output.h>\n#include <wlr/render/drm_format_set.h>\n')
    replace_once(header,
        'struct wlr_anland_backend {\n',
        'struct wlr_anland_buffer;\n\nstruct wlr_anland_backend {\n')
    replace_once(header,
        '    bool consumer_ready;\n',
        '''    bool consumer_ready;\n    bool output_published;\n    bool pool_ready;\n    bool buffer_writable;\n    bool force_full_repaint;\n    int drm_fd;\n    int selected_index;\n    uint64_t generation;\n    uint64_t present_count;\n    struct wl_event_source *buf_ready_source;\n    struct wlr_drm_format_set primary_formats;\n    struct wlr_anland_buffer *buffers[MAX_BUFS];\n    size_t buffer_count;\n''')
    replace_once(header,
        'void anland_output_consumer_state(struct wlr_anland_output *output, bool ready);\n',
        '''void anland_output_consumer_state(struct wlr_anland_output *output, bool ready);\nbool anland_buffer_pool_rebuild(struct wlr_anland_backend *backend);\nvoid anland_buffer_pool_finish(struct wlr_anland_backend *backend);\nstruct wlr_buffer *anland_acquire_selected_buffer(struct wlr_output *output,\n    const struct wlr_output_state *state);\nbool anland_buffer_is_current(struct wlr_anland_backend *backend,\n    struct wlr_buffer *buffer, int *index_out);\nint anland_export_render_fence(struct wlr_anland_backend *backend,\n    struct wlr_buffer *buffer);\nvoid anland_zero_copy_consumer_state(struct wlr_anland_backend *backend, bool ready);\n''')

    # Backend render-node setup.
    replace_once(backend, '#include <assert.h>\n',
        '#include <assert.h>\n#include <fcntl.h>\n#include <unistd.h>\n')
    replace_once(backend,
        '''static uint32_t get_buffer_caps(struct wlr_backend *wlr_backend) {\n    (void)wlr_backend;\n    return WLR_BUFFER_CAP_DATA_PTR | WLR_BUFFER_CAP_DMABUF | WLR_BUFFER_CAP_SHM;\n}\n''',
        '''static int get_drm_fd(struct wlr_backend *wlr_backend) {\n    struct wlr_anland_backend *backend = anland_backend_from_backend(wlr_backend);\n    return backend->drm_fd;\n}\n\nstatic uint32_t get_buffer_caps(struct wlr_backend *wlr_backend) {\n    (void)wlr_backend;\n    return WLR_BUFFER_CAP_DMABUF;\n}\n''')
    replace_once(backend,
        '    .destroy = backend_destroy,\n    .get_buffer_caps = get_buffer_caps,\n',
        '    .destroy = backend_destroy,\n    .get_drm_fd = get_drm_fd,\n    .get_buffer_caps = get_buffer_caps,\n')

    replace_once(backend,
        '    wlr_backend_init(&backend->backend, &backend_impl);\n',
        '''    wlr_backend_init(&backend->backend, &backend_impl);\n    backend->drm_fd = -1;\n    backend->selected_index = -1;\n    const char *drm_path = getenv("ANLAND_DRM_DEVICE");\n    if (drm_path == NULL || drm_path[0] == '\\0') {\n        drm_path = "/dev/dri/renderD128";\n    }\n    backend->drm_fd = open(drm_path, O_RDWR | O_CLOEXEC);\n    if (backend->drm_fd < 0) {\n        wlr_log_errno(WLR_ERROR, "Unable to open Anland render node %s", drm_path);\n        free(backend);\n        return NULL;\n    }\n    wlr_log(WLR_INFO, "Anland render node: %s fd=%d", drm_path, backend->drm_fd);\n''')

    # Replace consumer state publishing so pool import happens before output publication.
    start = 'static void publish_consumer_state(struct wlr_anland_backend *backend, bool ready) {'
    end = 'static int reconnect_timer(void *data) {'
    publish = r'''static void publish_consumer_state(struct wlr_anland_backend *backend, bool ready) {
    if (backend->consumer_ready == ready && (!ready || backend->pool_ready)) {
        return;
    }

    if (ready) {
        backend->consumer_ready = true;
        anland_zero_copy_consumer_state(backend, true);
        if (!backend->pool_ready) {
            backend->consumer_ready = false;
            anland_input_detach(backend);
            return;
        }
        anland_input_attach(backend);
        /* Output publication is deferred until Android signals buffer-ready,
         * so Labwc's initial modeset cannot render into a busy consumer buffer. */
    } else {
        backend->consumer_ready = false;
        anland_input_detach(backend);
        anland_zero_copy_consumer_state(backend, false);
    }

    struct wlr_anland_output *output;
    wl_list_for_each(output, &backend->outputs, link) {
        anland_output_consumer_state(output, ready);
    }
    wlr_log(WLR_INFO, "Anland Android consumer is %s", ready ? "ready" : "detached");
}

'''
    replace_between(backend, start, end, publish)

    # Backend start: don't expose an unusable output before consumer buffers exist.
    old_start_body = '''    struct wlr_anland_output *output;\n    wl_list_for_each(output, &backend->outputs, link) {\n        wl_signal_emit_mutable(&backend->backend.events.new_output,\n            &output->wlr_output);\n    }\n\n    backend->started = true;\n    anland_input_publish(backend);\n'''
    new_start_body = '''    backend->started = true;\n    anland_input_publish(backend);\n    /* First new_output is emitted from the first Android buffer-ready event. */\n'''
    replace_once(backend, old_start_body, new_start_body)

    # Ensure zero-copy resources and render node are torn down safely.
    replace_once(backend,
        '    anland_input_finish(backend);\n',
        '    anland_zero_copy_consumer_state(backend, false);\n    anland_input_finish(backend);\n')
    replace_once(backend,
        '''    if (backend->display != NULL) {\n        disconnect(backend->display);\n    }\n    wlr_backend_finish(wlr_backend);\n''',
        '''    if (backend->display != NULL) {\n        disconnect(backend->display);\n    }\n    if (backend->drm_fd >= 0) {\n        close(backend->drm_fd);\n        backend->drm_fd = -1;\n    }\n    wlr_backend_finish(wlr_backend);\n''')

    # Any create failure after opening drm_fd must close it. Keep this scoped to
    # the generated backend's constructor paths.
    text = backend.read_text()
    marker = '    backend->drm_fd = open(drm_path, O_RDWR | O_CLOEXEC);\n'
    pos = text.find(marker)
    if pos < 0:
        raise RuntimeError("drm open marker missing after insertion")
    prefix, suffix = text[:pos], text[pos:]
    suffix = suffix.replace(
        '        free(backend);\n        return NULL;\n',
        '        if (backend->drm_fd >= 0) close(backend->drm_fd);\n        free(backend);\n        return NULL;\n')
    backend.write_text(prefix + suffix)

    output.write_text(OUTPUT_C)
    (root / "backend/anland/buffer.c").write_text(BUFFER_C)
    replace_once(meson, "    'output.c',\n", "    'output.c',\n    'buffer.c',\n")

    # Keep the nested Weston bootstrap compatibility fix from Stage3 fixups.
    if 'wlr_output_state_set_custom_mode(&state, 1280, 720, 0);' in wayland_output.read_text():
        replace_once(wayland_output,
            'wlr_output_state_set_custom_mode(&state, 1280, 720, 0);\n',
            'wlr_output_state_set_custom_mode(&state, 1, 1, 0);\n')

    # Sanity assertions: Stage4 must not contain the old fullscreen presenter.
    joined = '\n'.join(p.read_text() for p in [header, backend, output, root / 'backend/anland/buffer.c', render])
    for forbidden in ('anland_presenter_blit', 'glFinish()', 'GPU-only EGL DMA-BUF blit'):
        if forbidden in joined:
            raise RuntimeError(f"Stage4 unexpectedly contains Stage3 presenter token: {forbidden}")
    if 'acquire_render_buffer' not in render.read_text():
        raise RuntimeError('wlroots render hook not installed')
    if 'Anland first zero-copy frame presented' not in output.read_text():
        raise RuntimeError('zero-copy presentation log missing')

    print(f"Stage4 zero-copy Anland overlay applied to {root}")


if __name__ == "__main__":
    main()
