#!/usr/bin/env python3
"""Apply Stage 3 GPU-only Anland presentation to the pinned wlroots 0.18.2 tree.

Stage 3 deliberately uses a backend-local surfaceless EGL/GLES2 blitter first:
Labwc/wlroots can keep its normal allocator, while the Anland output imports the
submitted wlroots DMA-BUF as a texture and the consumer-selected Anland DMA-BUF
as an FBO target. No CPU readback/upload is allowed.

This is the conservative first direct implementation. Once it is validated on
SM8750, the last GPU blit may be removed by teaching wlroots' allocator to hand
consumer-owned Anland buffers directly to the compositor.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if old not in text:
        raise RuntimeError(f"stage3 anchor not found in {path}: {old!r}")
    if text.count(old) != 1:
        raise RuntimeError(f"stage3 anchor not unique in {path}: {old!r}")
    path.write_text(text.replace(old, new, 1))


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


PRESENTER_H = r'''#ifndef BACKEND_ANLAND_PRESENTER_H
#define BACKEND_ANLAND_PRESENTER_H

#include <stdbool.h>
#include <stdint.h>
#include <wlr/types/wlr_buffer.h>

struct anland_presenter;
struct wlr_anland_backend;
struct wlr_anland_output;

struct anland_presenter *anland_presenter_create(void);
void anland_presenter_destroy(struct anland_presenter *presenter);

/* GPU-only copy from a wlroots output DMA-BUF into the currently selected
 * Android/Anland consumer DMA-BUF. This function is synchronous in stage 3
 * (glFinish) so the source buffer may be released by wlroots after commit. */
bool anland_presenter_blit(struct anland_presenter *presenter,
    struct wlr_anland_backend *backend, struct wlr_buffer *source);

/* Arm/disarm the consumer buffer-ready eventfd. Android owns buffer rotation;
 * wlroots emits a frame event only after Android announces a writable slot. */
void anland_presenter_consumer_state(struct wlr_anland_backend *backend,
    bool ready);

#endif
'''


PRESENTER_C = r'''#define _GNU_SOURCE
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <drm_fourcc.h>
#include <errno.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/eventfd.h>

#include <wlr/render/dmabuf.h>
#include <wlr/types/wlr_buffer.h>
#include <wlr/types/wlr_output.h>
#include <wlr/util/log.h>

#include "backend/anland.h"
#include "backend/anland/presenter.h"

#ifndef EGL_PLATFORM_SURFACELESS_MESA
#define EGL_PLATFORM_SURFACELESS_MESA 0x31DD
#endif
#ifndef EGL_LINUX_DMA_BUF_EXT
#define EGL_LINUX_DMA_BUF_EXT 0x3270
#endif
#ifndef EGL_LINUX_DRM_FOURCC_EXT
#define EGL_LINUX_DRM_FOURCC_EXT 0x3271
#endif
#ifndef EGL_DMA_BUF_PLANE0_FD_EXT
#define EGL_DMA_BUF_PLANE0_FD_EXT 0x3272
#define EGL_DMA_BUF_PLANE0_OFFSET_EXT 0x3273
#define EGL_DMA_BUF_PLANE0_PITCH_EXT 0x3274
#define EGL_DMA_BUF_PLANE1_FD_EXT 0x3275
#define EGL_DMA_BUF_PLANE1_OFFSET_EXT 0x3276
#define EGL_DMA_BUF_PLANE1_PITCH_EXT 0x3277
#define EGL_DMA_BUF_PLANE2_FD_EXT 0x3278
#define EGL_DMA_BUF_PLANE2_OFFSET_EXT 0x3279
#define EGL_DMA_BUF_PLANE2_PITCH_EXT 0x327A
#endif
#ifndef EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT
#define EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT 0x3443
#define EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT 0x3444
#define EGL_DMA_BUF_PLANE1_MODIFIER_LO_EXT 0x3445
#define EGL_DMA_BUF_PLANE1_MODIFIER_HI_EXT 0x3446
#define EGL_DMA_BUF_PLANE2_MODIFIER_LO_EXT 0x3447
#define EGL_DMA_BUF_PLANE2_MODIFIER_HI_EXT 0x3448
#endif

struct anland_presenter {
    EGLDisplay display;
    EGLContext context;
    PFNEGLGETPLATFORMDISPLAYEXTPROC get_platform_display;
    PFNEGLCREATEIMAGEKHRPROC create_image;
    PFNEGLDESTROYIMAGEKHRPROC destroy_image;
    PFNGLEGLIMAGETARGETTEXTURE2DOESPROC image_target_texture;
    GLuint program;
    GLint sampler_location;
    bool flip_y;
    struct wlr_buffer *last_source;
    uint64_t present_count;
};

static GLuint compile_shader(GLenum type, const char *source) {
    GLuint shader = glCreateShader(type);
    if (!shader) {
        return 0;
    }
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    GLint ok = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[1024] = {0};
        glGetShaderInfoLog(shader, sizeof(log) - 1, NULL, log);
        wlr_log(WLR_ERROR, "Anland GLES shader compilation failed: %s", log);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

static bool init_program(struct anland_presenter *p) {
    static const char *vs_source =
        "attribute vec2 pos; attribute vec2 uv; varying vec2 v_uv;"
        "void main(){ gl_Position=vec4(pos,0.0,1.0); v_uv=uv; }";
    static const char *fs_source =
        "precision mediump float; varying vec2 v_uv; uniform sampler2D tex;"
        "void main(){ gl_FragColor=texture2D(tex,v_uv); }";

    GLuint vs = compile_shader(GL_VERTEX_SHADER, vs_source);
    GLuint fs = compile_shader(GL_FRAGMENT_SHADER, fs_source);
    if (!vs || !fs) {
        if (vs) glDeleteShader(vs);
        if (fs) glDeleteShader(fs);
        return false;
    }
    p->program = glCreateProgram();
    glAttachShader(p->program, vs);
    glAttachShader(p->program, fs);
    glBindAttribLocation(p->program, 0, "pos");
    glBindAttribLocation(p->program, 1, "uv");
    glLinkProgram(p->program);
    glDeleteShader(vs);
    glDeleteShader(fs);
    GLint ok = GL_FALSE;
    glGetProgramiv(p->program, GL_LINK_STATUS, &ok);
    if (!ok) {
        char log[1024] = {0};
        glGetProgramInfoLog(p->program, sizeof(log) - 1, NULL, log);
        wlr_log(WLR_ERROR, "Anland GLES program link failed: %s", log);
        return false;
    }
    p->sampler_location = glGetUniformLocation(p->program, "tex");
    return true;
}

struct anland_presenter *anland_presenter_create(void) {
    struct anland_presenter *p = calloc(1, sizeof(*p));
    if (!p) {
        return NULL;
    }
    p->display = EGL_NO_DISPLAY;
    p->context = EGL_NO_CONTEXT;
    p->flip_y = getenv("NEWHOME_ANLAND_FLIP_Y") == NULL ||
        strcmp(getenv("NEWHOME_ANLAND_FLIP_Y"), "0") != 0;

    p->get_platform_display = (PFNEGLGETPLATFORMDISPLAYEXTPROC)
        eglGetProcAddress("eglGetPlatformDisplayEXT");
    p->create_image = (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
    p->destroy_image = (PFNEGLDESTROYIMAGEKHRPROC)eglGetProcAddress("eglDestroyImageKHR");
    p->image_target_texture = (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)
        eglGetProcAddress("glEGLImageTargetTexture2DOES");
    if (!p->get_platform_display || !p->create_image || !p->destroy_image ||
            !p->image_target_texture) {
        wlr_log(WLR_ERROR, "Anland presenter: required EGL/GLES extension entry points missing");
        goto fail;
    }

    p->display = p->get_platform_display(EGL_PLATFORM_SURFACELESS_MESA,
        EGL_DEFAULT_DISPLAY, NULL);
    if (p->display == EGL_NO_DISPLAY || !eglInitialize(p->display, NULL, NULL)) {
        wlr_log(WLR_ERROR, "Anland presenter: surfaceless EGL initialization failed (0x%x)",
            eglGetError());
        goto fail;
    }
    if (!eglBindAPI(EGL_OPENGL_ES_API)) {
        goto fail;
    }
    const EGLint ctx_attrs[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };
    p->context = eglCreateContext(p->display, EGL_NO_CONFIG_KHR, EGL_NO_CONTEXT, ctx_attrs);
    if (p->context == EGL_NO_CONTEXT ||
            !eglMakeCurrent(p->display, EGL_NO_SURFACE, EGL_NO_SURFACE, p->context)) {
        wlr_log(WLR_ERROR, "Anland presenter: GLES2 surfaceless context failed (0x%x)",
            eglGetError());
        goto fail;
    }
    if (!init_program(p)) {
        goto fail;
    }

    wlr_log(WLR_INFO, "Anland presenter initialized: GPU-only EGL DMA-BUF blit%s",
        p->flip_y ? " (Y-flip enabled)" : "");
    return p;

fail:
    anland_presenter_destroy(p);
    return NULL;
}

void anland_presenter_destroy(struct anland_presenter *p) {
    if (!p) return;
    if (p->last_source) {
        wlr_buffer_unlock(p->last_source);
        p->last_source = NULL;
    }
    if (p->display != EGL_NO_DISPLAY && p->context != EGL_NO_CONTEXT) {
        eglMakeCurrent(p->display, EGL_NO_SURFACE, EGL_NO_SURFACE, p->context);
        if (p->program) glDeleteProgram(p->program);
    }
    if (p->display != EGL_NO_DISPLAY && p->context != EGL_NO_CONTEXT) {
        eglDestroyContext(p->display, p->context);
    }
    if (p->display != EGL_NO_DISPLAY) {
        eglTerminate(p->display);
    }
    free(p);
}

static bool append_plane_attrs(EGLint *attrs, size_t *n,
        const struct wlr_dmabuf_attributes *dmabuf, int plane) {
    static const EGLint fd_key[] = {
        EGL_DMA_BUF_PLANE0_FD_EXT, EGL_DMA_BUF_PLANE1_FD_EXT,
        EGL_DMA_BUF_PLANE2_FD_EXT,
    };
    static const EGLint off_key[] = {
        EGL_DMA_BUF_PLANE0_OFFSET_EXT, EGL_DMA_BUF_PLANE1_OFFSET_EXT,
        EGL_DMA_BUF_PLANE2_OFFSET_EXT,
    };
    static const EGLint pitch_key[] = {
        EGL_DMA_BUF_PLANE0_PITCH_EXT, EGL_DMA_BUF_PLANE1_PITCH_EXT,
        EGL_DMA_BUF_PLANE2_PITCH_EXT,
    };
    static const EGLint mod_lo_key[] = {
        EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, EGL_DMA_BUF_PLANE1_MODIFIER_LO_EXT,
        EGL_DMA_BUF_PLANE2_MODIFIER_LO_EXT,
    };
    static const EGLint mod_hi_key[] = {
        EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, EGL_DMA_BUF_PLANE1_MODIFIER_HI_EXT,
        EGL_DMA_BUF_PLANE2_MODIFIER_HI_EXT,
    };
    if (plane < 0 || plane >= 3 || dmabuf->fd[plane] < 0) {
        return false;
    }
    attrs[(*n)++] = fd_key[plane]; attrs[(*n)++] = dmabuf->fd[plane];
    attrs[(*n)++] = off_key[plane]; attrs[(*n)++] = (EGLint)dmabuf->offset[plane];
    attrs[(*n)++] = pitch_key[plane]; attrs[(*n)++] = (EGLint)dmabuf->stride[plane];
    if (dmabuf->modifier != DRM_FORMAT_MOD_INVALID) {
        attrs[(*n)++] = mod_lo_key[plane];
        attrs[(*n)++] = (EGLint)(dmabuf->modifier & 0xffffffffu);
        attrs[(*n)++] = mod_hi_key[plane];
        attrs[(*n)++] = (EGLint)(dmabuf->modifier >> 32);
    }
    return true;
}

static EGLImageKHR import_dmabuf(struct anland_presenter *p,
        const struct wlr_dmabuf_attributes *dmabuf) {
    if (dmabuf->n_planes < 1 || dmabuf->n_planes > 3) {
        wlr_log(WLR_ERROR, "Anland presenter supports 1-3 plane DMA-BUFs, got %d",
            dmabuf->n_planes);
        return EGL_NO_IMAGE_KHR;
    }
    EGLint attrs[64];
    size_t n = 0;
    attrs[n++] = EGL_WIDTH; attrs[n++] = dmabuf->width;
    attrs[n++] = EGL_HEIGHT; attrs[n++] = dmabuf->height;
    attrs[n++] = EGL_LINUX_DRM_FOURCC_EXT; attrs[n++] = (EGLint)dmabuf->format;
    for (int i = 0; i < dmabuf->n_planes; ++i) {
        if (!append_plane_attrs(attrs, &n, dmabuf, i)) {
            return EGL_NO_IMAGE_KHR;
        }
    }
    attrs[n++] = EGL_NONE;
    return p->create_image(p->display, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT,
        NULL, attrs);
}

static uint32_t protocol_format_to_drm(uint32_t format) {
    switch (format) {
    case 1: /* Android PIXEL_FORMAT_RGBA_8888, R8G8B8A8 memory */
        return DRM_FORMAT_ABGR8888;
    default:
        return 0;
    }
}

static bool target_attributes(struct wlr_anland_backend *backend,
        struct wlr_dmabuf_attributes *attrs) {
    memset(attrs, 0, sizeof(*attrs));
    for (int i = 0; i < WLR_DMABUF_MAX_PLANES; ++i) attrs->fd[i] = -1;

    int index = get_selected_idx(backend->display);
    int fd = get_dmabuf_fd_at(backend->display, index);
    struct buf_info info;
    memset(&info, 0, sizeof(info));
    if (fd < 0 || get_dmabuf_info_at(backend->display, index, &info) < 0) {
        return false;
    }
    uint32_t drm_format = protocol_format_to_drm(info.format);
    if (!drm_format) {
        wlr_log(WLR_ERROR, "Unsupported Anland consumer pixel format %u", info.format);
        return false;
    }
    attrs->width = backend->width;
    attrs->height = backend->height;
    attrs->format = drm_format;
    attrs->modifier = info.modifier;
    attrs->n_planes = 1;
    attrs->fd[0] = fd;
    attrs->offset[0] = info.offset;
    attrs->stride[0] = info.stride;
    return true;
}

bool anland_presenter_blit(struct anland_presenter *p,
        struct wlr_anland_backend *backend, struct wlr_buffer *source) {
    if (!p || !backend || !source || !backend->consumer_ready ||
            is_fallback(backend->display)) {
        return false;
    }

    struct wlr_dmabuf_attributes src;
    memset(&src, 0, sizeof(src));
    for (int i = 0; i < WLR_DMABUF_MAX_PLANES; ++i) src.fd[i] = -1;
    if (!wlr_buffer_get_dmabuf(source, &src)) {
        wlr_log(WLR_ERROR,
            "Anland direct output received a non-DMA-BUF wlroots buffer; refusing CPU fallback");
        return false;
    }
    struct wlr_dmabuf_attributes dst;
    if (!target_attributes(backend, &dst)) {
        wlr_log(WLR_ERROR, "Anland consumer DMA-BUF metadata unavailable");
        return false;
    }

    EGLDisplay previous_display = eglGetCurrentDisplay();
    EGLContext previous_context = eglGetCurrentContext();
    EGLSurface previous_draw = eglGetCurrentSurface(EGL_DRAW);
    EGLSurface previous_read = eglGetCurrentSurface(EGL_READ);
    if (!eglMakeCurrent(p->display, EGL_NO_SURFACE, EGL_NO_SURFACE, p->context)) {
        return false;
    }
    EGLImageKHR src_image = import_dmabuf(p, &src);
    EGLImageKHR dst_image = import_dmabuf(p, &dst);
    if (src_image == EGL_NO_IMAGE_KHR || dst_image == EGL_NO_IMAGE_KHR) {
        wlr_log(WLR_ERROR,
            "Anland DMA-BUF EGL import failed: src_fmt=0x%x dst_fmt=0x%x error=0x%x",
            src.format, dst.format, eglGetError());
        if (src_image != EGL_NO_IMAGE_KHR) p->destroy_image(p->display, src_image);
        if (dst_image != EGL_NO_IMAGE_KHR) p->destroy_image(p->display, dst_image);
        if (previous_display != EGL_NO_DISPLAY) {
            eglMakeCurrent(previous_display, previous_draw, previous_read, previous_context);
        }
        return false;
    }

    GLuint src_tex = 0, dst_tex = 0, fbo = 0;
    glGenTextures(1, &src_tex);
    glBindTexture(GL_TEXTURE_2D, src_tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    p->image_target_texture(GL_TEXTURE_2D, src_image);

    glGenTextures(1, &dst_tex);
    glBindTexture(GL_TEXTURE_2D, dst_tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    p->image_target_texture(GL_TEXTURE_2D, dst_image);

    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
        GL_TEXTURE_2D, dst_tex, 0);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        wlr_log(WLR_ERROR, "Anland target DMA-BUF is not GLES-renderable");
        goto fail;
    }

    const GLfloat verts[] = {
        -1.f, -1.f,  0.f, p->flip_y ? 1.f : 0.f,
         1.f, -1.f,  1.f, p->flip_y ? 1.f : 0.f,
        -1.f,  1.f,  0.f, p->flip_y ? 0.f : 1.f,
         1.f,  1.f,  1.f, p->flip_y ? 0.f : 1.f,
    };
    glViewport(0, 0, (GLsizei)backend->width, (GLsizei)backend->height);
    glDisable(GL_BLEND);
    glUseProgram(p->program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, src_tex);
    glUniform1i(p->sampler_location, 0);
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), verts);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), verts + 2);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisableVertexAttribArray(0);
    glDisableVertexAttribArray(1);

    /* Stage 3 uses a conservative synchronous fence. This is still GPU-only:
     * it waits for GPU completion but never maps/readbacks framebuffer pixels.
     * Explicit native fence sync is the follow-up optimization. */
    glFinish();
    if (glGetError() != GL_NO_ERROR) {
        wlr_log(WLR_ERROR, "Anland GLES blit reported an error");
        goto fail;
    }

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &fbo);
    glDeleteTextures(1, &src_tex);
    glDeleteTextures(1, &dst_tex);
    p->destroy_image(p->display, src_image);
    p->destroy_image(p->display, dst_image);
    if (previous_display != EGL_NO_DISPLAY) {
        /* presenter 与 wlroots 共用主线程，必须恢复 Labwc 的 EGL context。 */
        eglMakeCurrent(previous_display, previous_draw, previous_read, previous_context);
    }
    return trigger_refresh(backend->display) == 0;

fail:
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (fbo) glDeleteFramebuffers(1, &fbo);
    if (src_tex) glDeleteTextures(1, &src_tex);
    if (dst_tex) glDeleteTextures(1, &dst_tex);
    p->destroy_image(p->display, src_image);
    p->destroy_image(p->display, dst_image);
    if (previous_display != EGL_NO_DISPLAY) {
        eglMakeCurrent(previous_display, previous_draw, previous_read, previous_context);
    }
    return false;
}

static int handle_buffer_ready(int fd, uint32_t mask, void *data) {
    (void)mask;
    struct wlr_anland_backend *backend = data;
    eventfd_t value;
    if (eventfd_read(fd, &value) < 0 && errno != EAGAIN) {
        wlr_log_errno(WLR_ERROR, "Failed reading Anland buffer-ready eventfd");
        return 0;
    }
    /* 先让合成器处理新 damage；若本轮没有产生新提交，再复制最后一帧。
     * 这样既能更新窗口/指针，也能维持静态桌面的四缓冲轮转。 */
    uint64_t before = backend->presenter->present_count;
    struct wlr_anland_output *output;
    wl_list_for_each(output, &backend->outputs, link) {
        wlr_output_send_frame(&output->wlr_output);
    }
    if (backend->presenter->present_count == before &&
            backend->presenter->last_source) {
        if (!anland_presenter_blit(backend->presenter, backend,
                backend->presenter->last_source)) {
            wlr_log(WLR_ERROR, "Anland cached-frame presentation failed");
        }
    }
    return 0;
}

void anland_presenter_consumer_state(struct wlr_anland_backend *backend,
        bool ready) {
    if (backend->buf_ready_source != NULL) {
        wl_event_source_remove(backend->buf_ready_source);
        backend->buf_ready_source = NULL;
    }
    if (!ready || backend->display == NULL || is_fallback(backend->display)) {
        return;
    }
    int fd = get_buffer_ready_fd(backend->display);
    if (fd < 0) {
        wlr_log(WLR_ERROR, "Anland consumer has no buffer-ready eventfd");
        return;
    }
    backend->buf_ready_source = wl_event_loop_add_fd(backend->event_loop, fd,
        WL_EVENT_READABLE, handle_buffer_ready, backend);
    if (backend->buf_ready_source == NULL) {
        wlr_log(WLR_ERROR, "Unable to watch Anland buffer-ready eventfd");
    }
}
'''


OUTPUT_C = r'''#include <assert.h>
#include <inttypes.h>
#include <stdlib.h>

#include <wlr/backend/anland.h>
#include <wlr/interfaces/wlr_output.h>
#include <wlr/util/log.h>

#include "backend/anland.h"
#include "backend/anland/presenter.h"
#include "types/wlr_output.h"

static const uint32_t SUPPORTED_OUTPUT_STATE =
    WLR_OUTPUT_STATE_BACKEND_OPTIONAL |
    WLR_OUTPUT_STATE_ENABLED |
    WLR_OUTPUT_STATE_MODE |
    WLR_OUTPUT_STATE_BUFFER |
    WLR_OUTPUT_STATE_DAMAGE;

static struct wlr_anland_output *anland_output_from_output(struct wlr_output *wlr_output) {
    assert(wlr_output_is_anland(wlr_output));
    return wl_container_of(wlr_output, (struct wlr_anland_output *)0, wlr_output);
}

static bool output_test(struct wlr_output *wlr_output,
        const struct wlr_output_state *state) {
    struct wlr_anland_output *output = anland_output_from_output(wlr_output);
    uint32_t unsupported = state->committed & ~SUPPORTED_OUTPUT_STATE;
    if (unsupported != 0) {
        wlr_log(WLR_DEBUG,
            "Anland rejects unsupported output state fields: 0x%"PRIx32,
            unsupported);
        return false;
    }
    if (state->committed & WLR_OUTPUT_STATE_MODE) {
        if (state->mode_type != WLR_OUTPUT_STATE_MODE_CUSTOM ||
                state->custom_mode.width != (int32_t)output->backend->width ||
                state->custom_mode.height != (int32_t)output->backend->height) {
            wlr_log(WLR_ERROR, "Anland output mode is fixed by Android consumer metadata");
            return false;
        }
    }
    if (state->committed & WLR_OUTPUT_STATE_BUFFER) {
        if (state->buffer == NULL || !output->backend->consumer_ready ||
                is_fallback(output->backend->display)) {
            return false;
        }
    }
    return true;
}

static bool output_commit(struct wlr_output *wlr_output,
        const struct wlr_output_state *state) {
    struct wlr_anland_output *output = anland_output_from_output(wlr_output);
    if (!output_test(wlr_output, state)) {
        return false;
    }
    if (state->committed & WLR_OUTPUT_STATE_BUFFER) {
        if (!anland_presenter_blit(output->backend->presenter,
                output->backend, state->buffer)) {
            wlr_log(WLR_ERROR, "Anland GPU DMA-BUF presentation failed");
            return false;
        }
    }
    return true;
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
    .test = output_test,
    .commit = output_commit,
};

bool wlr_output_is_anland(struct wlr_output *output) {
    return output != NULL && output->impl == &output_impl;
}

static int bootstrap_frame(void *data) {
    struct wlr_anland_output *output = data;
    if (output->backend->consumer_ready) {
        wlr_output_send_frame(&output->wlr_output);
    }
    return 0;
}

void anland_output_consumer_state(struct wlr_anland_output *output, bool ready) {
    if (ready && output->frame_timer != NULL) {
        /* One bootstrap frame starts the Android buffer-ready cadence. */
        wl_event_source_timer_update(output->frame_timer, 1);
    }
}

struct wlr_output *anland_backend_add_output(struct wlr_anland_backend *backend) {
    struct wlr_anland_output *output = calloc(1, sizeof(*output));
    if (output == NULL) {
        return NULL;
    }
    output->backend = backend;

    int32_t refresh = backend->refresh > INT32_MAX ? 0 : (int32_t)backend->refresh;
    struct wlr_output_state state;
    wlr_output_state_init(&state);
    wlr_output_state_set_custom_mode(&state,
        (int32_t)backend->width, (int32_t)backend->height, refresh);
    wlr_output_init(&output->wlr_output, &backend->backend, &output_impl,
        backend->event_loop, &state);
    wlr_output_state_finish(&state);

    wlr_output_set_name(&output->wlr_output, "ANLAND-1");
    wlr_output_set_description(&output->wlr_output,
        "Anland Android display (GPU DMA-BUF direct backend)");

    output->frame_timer = wl_event_loop_add_timer(backend->event_loop,
        bootstrap_frame, output);
    if (output->frame_timer == NULL) {
        free(output);
        return NULL;
    }

    wl_list_insert(&backend->outputs, &output->link);
    if (backend->started) {
        wl_signal_emit_mutable(&backend->backend.events.new_output,
            &output->wlr_output);
    }
    return &output->wlr_output;
}
'''


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    root = args.source.resolve()

    output = root / "backend/anland/output.c"
    backend_h = root / "backend/anland.h"
    backend_c = root / "backend/anland/backend.c"
    meson = root / "backend/anland/meson.build"
    for path in (output, backend_h, backend_c, meson):
        if not path.exists():
            raise RuntimeError(f"stage1/2 prerequisite missing: {path}")

    # Stage 3 owns the final output implementation.
    write(output, OUTPUT_C)
    write(root / "backend/anland/presenter.h", PRESENTER_H)
    write(root / "backend/anland/presenter.c", PRESENTER_C)

    replace_once(
        backend_h,
        'struct wlr_anland_backend {\n',
        'struct anland_presenter;\n\nstruct wlr_anland_backend {\n',
    )
    replace_once(
        backend_h,
        '    struct wl_event_source *reconnect_timer;\n',
        '    struct wl_event_source *reconnect_timer;\n'
        '    struct wl_event_source *buf_ready_source;\n'
        '    struct anland_presenter *presenter;\n',
    )

    replace_once(
        backend_c,
        '#include "backend/anland.h"\n',
        '#include "backend/anland.h"\n#include "backend/anland/presenter.h"\n',
    )
    replace_once(
        backend_c,
        '    backend->consumer_ready = ready;\n',
        '    backend->consumer_ready = ready;\n'
        '    anland_presenter_consumer_state(backend, ready);\n',
    )
    replace_once(
        backend_c,
        '    if (backend->reconnect_timer != NULL) {\n'
        '        wl_event_source_remove(backend->reconnect_timer);\n'
        '    }\n',
        '    if (backend->buf_ready_source != NULL) {\n'
        '        wl_event_source_remove(backend->buf_ready_source);\n'
        '        backend->buf_ready_source = NULL;\n'
        '    }\n'
        '    if (backend->reconnect_timer != NULL) {\n'
        '        wl_event_source_remove(backend->reconnect_timer);\n'
        '    }\n'
        '    anland_presenter_destroy(backend->presenter);\n'
        '    backend->presenter = NULL;\n',
    )
    replace_once(
        backend_c,
        '    set_fallback_callback(backend->display, handle_fallback, backend);\n',
        '    backend->presenter = anland_presenter_create();\n'
        '    if (backend->presenter == NULL) {\n'
        '        wlr_log(WLR_ERROR, "Unable to initialize Anland GPU presenter");\n'
        '        disconnect(backend->display);\n'
        '        free(backend->socket_path);\n'
        '        free(backend);\n'
        '        return NULL;\n'
        '    }\n\n'
        '    set_fallback_callback(backend->display, handle_fallback, backend);\n',
    )

    # Direct stage 3 requires the compositor to submit DMA-BUF-backed output
    # buffers. Do not advertise SHM/data-pointer-only caps anymore.
    replace_once(
        backend_c,
        '    return WLR_BUFFER_CAP_DATA_PTR | WLR_BUFFER_CAP_SHM;\n',
        '    return WLR_BUFFER_CAP_DMABUF;\n',
    )

    replace_once(
        meson,
        "    'output.c',\n",
        "    'output.c',\n    'presenter.c',\n",
    )

    print("stage3 GPU DMA-BUF presentation overlay applied")


if __name__ == "__main__":
    main()
