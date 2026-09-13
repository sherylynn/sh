#include <assert.h>
#include <drm_fourcc.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

#include <wlr/backend/anland.h>
#include <wlr/interfaces/wlr_output.h>
#include <wlr/render/drm_format_set.h>
#include <wlr/types/wlr_output.h>
#include <wlr/util/log.h>

#include "backend/anland.h"

static const uint32_t SUPPORTED_OUTPUT_STATE =
    WLR_OUTPUT_STATE_BACKEND_OPTIONAL |
    WLR_OUTPUT_STATE_MODE |
    WLR_OUTPUT_STATE_ENABLED |
    WLR_OUTPUT_STATE_BUFFER;

static struct wlr_anland_output *anland_output_from_output(
        struct wlr_output *wlr_output) {
    assert(wlr_output_is_anland(wlr_output));
    return (struct wlr_anland_output *)wlr_output;
}

static bool output_test(struct wlr_output *wlr_output,
        const struct wlr_output_state *state) {
    struct wlr_anland_output *output = anland_output_from_output(wlr_output);
    uint32_t unsupported = state->committed & ~SUPPORTED_OUTPUT_STATE;
    if (unsupported != 0) {
        wlr_log(WLR_DEBUG,
            "Anland zero-copy rejects unsupported output state fields: 0x%"PRIx32,
            unsupported);
        return false;
    }
    if ((state->committed & WLR_OUTPUT_STATE_MODE) &&
            state->mode_type != WLR_OUTPUT_STATE_MODE_CUSTOM) {
        return false;
    }
    if ((state->committed & WLR_OUTPUT_STATE_BUFFER) && state->buffer != NULL &&
            output->backend->consumer_ready &&
            !anland_buffer_is_current(output->backend, state->buffer, NULL)) {
        wlr_log(WLR_ERROR, "Anland zero-copy rejected non-consumer render buffer");
        return false;
    }
    return true;
}

static bool output_commit(struct wlr_output *wlr_output,
        const struct wlr_output_state *state) {
    struct wlr_anland_output *output = anland_output_from_output(wlr_output);
    struct wlr_anland_backend *backend = output->backend;
    if (!output_test(wlr_output, state)) {
        return false;
    }

    if (state->committed & WLR_OUTPUT_STATE_BUFFER) {
        if (!backend->consumer_ready || !backend->pool_ready ||
                is_fallback(backend->display)) {
            return false;
        }
        int index = -1;
        if (!anland_buffer_is_current(backend, state->buffer, &index)) {
            return false;
        }
        int selected = get_selected_idx(backend->display);
        if (selected != index) {
            wlr_log(WLR_ERROR,
                "Anland zero-copy buffer rotation mismatch: rendered=%d selected=%d",
                index, selected);
            return false;
        }

        /* The renderer has already submitted work directly into this Anland
         * DMA-BUF. Export its implicit reservation fence when supported, matching
         * upstream Weston-Anland's asynchronous fence handoff semantics. */
        int fence_fd = anland_export_render_fence(backend, state->buffer);
        set_render_fence(backend->display, fence_fd);
        if (trigger_refresh(backend->display) != 0) {
            wlr_log(WLR_ERROR, "Anland zero-copy trigger_refresh failed");
            return false;
        }
        /* libdisplay_producer owns/forwards the fence after set_render_fence(). */
        backend->buffer_writable = false;

        backend->present_count++;
        if (backend->present_count == 1) {
            wlr_log(WLR_INFO,
                "Anland first zero-copy frame presented: direct consumer DMA-BUF render");
        }

        struct timespec now;
        clock_gettime(CLOCK_MONOTONIC, &now);
        struct wlr_output_event_present event = {
            .commit_seq = wlr_output->commit_seq + 1,
            .presented = true,
            .when = now,
            .refresh = backend->refresh > 0 ? (int)(1000000000000LL / backend->refresh) : 0,
            .flags = WLR_OUTPUT_PRESENT_ZERO_COPY,
        };
        wlr_output_send_present(wlr_output, &event);
    }
    return true;
}

static void output_destroy(struct wlr_output *wlr_output) {
    struct wlr_anland_output *output = anland_output_from_output(wlr_output);
    wl_list_remove(&output->link);
    free(output);
}

static const struct wlr_drm_format_set *output_get_primary_formats(
        struct wlr_output *wlr_output, uint32_t buffer_caps) {
    struct wlr_anland_output *output = anland_output_from_output(wlr_output);
    if (!(buffer_caps & WLR_BUFFER_CAP_DMABUF) || !output->backend->pool_ready) {
        return NULL;
    }
    return &output->backend->primary_formats;
}

static const struct wlr_output_impl output_impl = {
    .destroy = output_destroy,
    .test = output_test,
    .commit = output_commit,
    .get_primary_formats = output_get_primary_formats,
    .acquire_render_buffer = anland_acquire_selected_buffer,
};

bool wlr_output_is_anland(struct wlr_output *output) {
    return output != NULL && output->impl == &output_impl;
}

void anland_output_consumer_state(struct wlr_anland_output *output, bool ready) {
    (void)output;
    (void)ready;
    /* Global buffer-ready eventfd drives frame scheduling in buffer.c. */
}

struct wlr_output *anland_backend_add_output(struct wlr_anland_backend *backend) {
    struct wlr_anland_output *output = calloc(1, sizeof(*output));
    if (output == NULL) {
        return NULL;
    }
    output->backend = backend;

    struct wlr_output_state state;
    wlr_output_state_init(&state);
    wlr_output_state_set_custom_mode(&state,
        (int32_t)backend->width, (int32_t)backend->height,
        backend->refresh > INT32_MAX ? 0 : (int32_t)backend->refresh);
    wlr_output_init(&output->wlr_output, &backend->backend, &output_impl,
        backend->event_loop, &state);
    wlr_output_state_finish(&state);
    wlr_output_set_name(&output->wlr_output, "ANLAND-1");
    wlr_output_set_description(&output->wlr_output,
        "Anland Android display (wlroots zero-copy consumer DMA-BUF)");
    output->wlr_output.render_format = DRM_FORMAT_ABGR8888;

    wl_list_insert(&backend->outputs, &output->link);
    return &output->wlr_output;
}
