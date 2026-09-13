#define _GNU_SOURCE
#include <drm_fourcc.h>
#include <errno.h>
#include <linux/dma-buf.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/eventfd.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <wlr/interfaces/wlr_buffer.h>
#include <wlr/interfaces/wlr_output.h>
#include <wlr/render/drm_format_set.h>
#include <wlr/types/wlr_buffer.h>
#include <wlr/types/wlr_output.h>
#include <wlr/util/log.h>

#include "backend/anland.h"

struct wlr_anland_buffer {
    struct wlr_buffer base;
    struct wlr_anland_backend *backend;
    struct wlr_dmabuf_attributes attrs;
    uint64_t generation;
    int index;
};

static struct wlr_anland_buffer *buffer_from_wlr(struct wlr_buffer *base) {
    return (struct wlr_anland_buffer *)base;
}

static void anland_buffer_destroy(struct wlr_buffer *base) {
    struct wlr_anland_buffer *buffer = buffer_from_wlr(base);
    wlr_buffer_finish(base);
    /* DMA-BUF FDs are borrowed from libdisplay_producer. Never close them here. */
    free(buffer);
}

static bool anland_buffer_get_dmabuf(struct wlr_buffer *base,
        struct wlr_dmabuf_attributes *attrs) {
    struct wlr_anland_buffer *buffer = buffer_from_wlr(base);
    *attrs = buffer->attrs;
    return true;
}

static const struct wlr_buffer_impl anland_buffer_impl = {
    .destroy = anland_buffer_destroy,
    .get_dmabuf = anland_buffer_get_dmabuf,
};

static uint32_t protocol_format_to_drm(uint32_t format) {
    switch (format) {
    case 1: /* Android PIXEL_FORMAT_RGBA_8888: R8G8B8A8 memory layout */
        return DRM_FORMAT_ABGR8888;
    default:
        /* Matches the upstream Weston-Anland compatibility fallback. */
        return DRM_FORMAT_XRGB8888;
    }
}

void anland_buffer_pool_finish(struct wlr_anland_backend *backend) {
    for (size_t i = 0; i < MAX_BUFS; ++i) {
        if (backend->buffers[i] != NULL) {
            wlr_buffer_drop(&backend->buffers[i]->base);
            backend->buffers[i] = NULL;
        }
    }
    backend->buffer_count = 0;
    backend->selected_index = -1;
    backend->pool_ready = false;
    wlr_drm_format_set_finish(&backend->primary_formats);
    memset(&backend->primary_formats, 0, sizeof(backend->primary_formats));
}

bool anland_buffer_pool_rebuild(struct wlr_anland_backend *backend) {
    anland_buffer_pool_finish(backend);

    int count = get_buf_count(backend->display);
    if (count <= 0 || count > MAX_BUFS) {
        wlr_log(WLR_ERROR, "Anland zero-copy: invalid consumer buffer count %d", count);
        return false;
    }

    struct buf_info first = {0};
    if (get_dmabuf_info_at(backend->display, 0, &first) < 0 ||
            first.width <= 0 || first.height <= 0) {
        wlr_log(WLR_ERROR, "Anland zero-copy: missing first DMA-BUF metadata");
        return false;
    }

    backend->width = (uint32_t)first.width;
    backend->height = (uint32_t)first.height;
    backend->generation++;

    for (int i = 0; i < count; ++i) {
        int fd = get_dmabuf_fd_at(backend->display, i);
        struct buf_info info = {0};
        if (fd < 0 || get_dmabuf_info_at(backend->display, i, &info) < 0) {
            wlr_log(WLR_ERROR, "Anland zero-copy: missing DMA-BUF[%d]", i);
            goto fail;
        }
        if (info.width != first.width || info.height != first.height) {
            wlr_log(WLR_ERROR, "Anland zero-copy: inconsistent DMA-BUF dimensions");
            goto fail;
        }

        uint32_t drm_format = protocol_format_to_drm(info.format);
        struct wlr_anland_buffer *buffer = calloc(1, sizeof(*buffer));
        if (buffer == NULL) {
            goto fail;
        }
        buffer->backend = backend;
        buffer->index = i;
        buffer->generation = backend->generation;
        buffer->attrs.width = info.width;
        buffer->attrs.height = info.height;
        buffer->attrs.format = drm_format;
        buffer->attrs.modifier = info.modifier;
        buffer->attrs.n_planes = 1;
        for (int p = 0; p < WLR_DMABUF_MAX_PLANES; ++p) {
            buffer->attrs.fd[p] = -1;
        }
        buffer->attrs.fd[0] = fd;
        buffer->attrs.offset[0] = info.offset;
        buffer->attrs.stride[0] = info.stride;
        wlr_buffer_init(&buffer->base, &anland_buffer_impl, info.width, info.height);
        backend->buffers[i] = buffer;

        if (!wlr_drm_format_set_add(&backend->primary_formats,
                drm_format, info.modifier)) {
            wlr_log(WLR_ERROR,
                "Anland zero-copy: failed to advertise format=0x%x modifier=0x%"PRIx64,
                drm_format, (uint64_t)info.modifier);
            goto fail;
        }

        wlr_log(WLR_INFO,
            "Anland zero-copy buffer[%d]: fd=%d %dx%d stride=%u format=0x%x modifier=0x%"PRIx64,
            i, fd, info.width, info.height, info.stride,
            drm_format, (uint64_t)info.modifier);
    }

    backend->buffer_count = (size_t)count;
    backend->pool_ready = true;
    wlr_log(WLR_INFO, "Anland zero-copy pool imported: %d consumer DMA-BUFs generation=%"PRIu64,
        count, backend->generation);
    return true;

fail:
    anland_buffer_pool_finish(backend);
    return false;
}

struct wlr_buffer *anland_acquire_selected_buffer(struct wlr_output *wlr_output,
        const struct wlr_output_state *state) {
    (void)state;
    struct wlr_anland_output *output = (struct wlr_anland_output *)wlr_output;
    struct wlr_anland_backend *backend = output->backend;
    if (!backend->consumer_ready || !backend->pool_ready ||
            !backend->buffer_writable || is_fallback(backend->display)) {
        return NULL;
    }

    int index = get_selected_idx(backend->display);
    if (index < 0 || (size_t)index >= backend->buffer_count ||
            backend->buffers[index] == NULL) {
        wlr_log(WLR_ERROR, "Anland zero-copy: consumer selected invalid buffer %d", index);
        return NULL;
    }

    backend->selected_index = index;
    return wlr_buffer_lock(&backend->buffers[index]->base);
}

bool anland_buffer_is_current(struct wlr_anland_backend *backend,
        struct wlr_buffer *base, int *index_out) {
    if (base == NULL || base->impl != &anland_buffer_impl) {
        return false;
    }
    struct wlr_anland_buffer *buffer = buffer_from_wlr(base);
    if (buffer->backend != backend || buffer->generation != backend->generation ||
            buffer->index < 0 || (size_t)buffer->index >= backend->buffer_count ||
            backend->buffers[buffer->index] != buffer) {
        return false;
    }
    if (index_out != NULL) {
        *index_out = buffer->index;
    }
    return true;
}

static int export_dmabuf_render_fence(int fd) {
#ifdef DMA_BUF_IOCTL_EXPORT_SYNC_FILE
    struct dma_buf_export_sync_file export = {
        .flags = DMA_BUF_SYNC_WRITE,
        .fd = -1,
    };
    if (ioctl(fd, DMA_BUF_IOCTL_EXPORT_SYNC_FILE, &export) == 0) {
        return export.fd;
    }
    if (errno != ENOTTY && errno != EINVAL && errno != ENOSYS) {
        wlr_log_errno(WLR_DEBUG, "Anland zero-copy: DMA-BUF sync_file export failed");
    }
#else
    (void)fd;
#endif
    return -1;
}

int anland_export_render_fence(struct wlr_anland_backend *backend,
        struct wlr_buffer *base) {
    int index = -1;
    if (!anland_buffer_is_current(backend, base, &index)) {
        return -1;
    }
    return export_dmabuf_render_fence(backend->buffers[index]->attrs.fd[0]);
}

static int handle_buffer_ready(int fd, uint32_t mask, void *data) {
    struct wlr_anland_backend *backend = data;
    if (mask & (WL_EVENT_HANGUP | WL_EVENT_ERROR)) {
        return 0;
    }
    eventfd_t value;
    if (eventfd_read(fd, &value) < 0 && errno != EAGAIN) {
        wlr_log_errno(WLR_ERROR, "Failed reading Anland buffer-ready eventfd");
        return 0;
    }
    backend->buffer_writable = true;
    struct wlr_anland_output *output;
    if (backend->started && !backend->output_published) {
        wl_list_for_each(output, &backend->outputs, link) {
            wl_signal_emit_mutable(&backend->backend.events.new_output,
                &output->wlr_output);
        }
        backend->output_published = true;
        return 0;
    }
    wl_list_for_each(output, &backend->outputs, link) {
        if (backend->force_full_repaint) {
            pixman_region32_t full;
            pixman_region32_init_rect(&full, 0, 0, backend->width, backend->height);
            struct wlr_output_event_damage event = {
                .output = &output->wlr_output,
                .damage = &full,
            };
            wl_signal_emit_mutable(&output->wlr_output.events.damage, &event);
            pixman_region32_fini(&full);
        }
        wlr_output_send_frame(&output->wlr_output);
    }
    backend->force_full_repaint = false;
    return 0;
}

void anland_zero_copy_consumer_state(struct wlr_anland_backend *backend,
        bool ready) {
    if (backend->buf_ready_source != NULL) {
        wl_event_source_remove(backend->buf_ready_source);
        backend->buf_ready_source = NULL;
    }

    if (!ready) {
        backend->buffer_writable = false;
        backend->force_full_repaint = false;
        anland_buffer_pool_finish(backend);
        return;
    }
    if (backend->display == NULL || is_fallback(backend->display)) {
        return;
    }
    if (!anland_buffer_pool_rebuild(backend)) {
        wlr_log(WLR_ERROR, "Anland zero-copy: consumer pool import failed");
        return;
    }
    struct wlr_anland_output *mode_output;
    wl_list_for_each(mode_output, &backend->outputs, link) {
        wlr_output_update_custom_mode(&mode_output->wlr_output,
            (int32_t)backend->width, (int32_t)backend->height,
            backend->refresh > INT32_MAX ? 0 : (int32_t)backend->refresh);
    }

    int fd = get_buffer_ready_fd(backend->display);
    if (fd < 0) {
        wlr_log(WLR_ERROR, "Anland zero-copy: consumer has no buffer-ready eventfd");
        anland_buffer_pool_finish(backend);
        return;
    }
    backend->buf_ready_source = wl_event_loop_add_fd(backend->event_loop, fd,
        WL_EVENT_READABLE | WL_EVENT_HANGUP | WL_EVENT_ERROR,
        handle_buffer_ready, backend);
    if (backend->buf_ready_source == NULL) {
        wlr_log(WLR_ERROR, "Anland zero-copy: unable to watch buffer-ready eventfd");
        anland_buffer_pool_finish(backend);
        return;
    }

    backend->buffer_writable = false;
    backend->force_full_repaint = true;
    /* Do not render yet. Weston-Anland also waits for buffer-ready before the
     * producer touches the consumer-selected DMA-BUF. */
}
