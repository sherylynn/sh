# wlroots-anland direct backend workspace

Final target:

```text
XFCE components
      |
    Labwc
      |
wlroots 0.18.2 + Anland backend
      |
 Anland 5.13.3
      |
   Android
```

The existing Weston-Anland path remains a bootstrap/fallback and A/B reference.

## Version policy

We do **not** fork Anland or Labwc for the first implementation.

- Android consumer + Termux daemon: upstream `lfdevs/anland-termux` **5.13.3**
- Debian: **13 / trixie**
- Labwc: distro **0.8.3**
- wlroots ABI: upstream **0.18.2**, Debian **0.18.2-3**

Only wlroots needs the Anland display backend. The source-overlay/build pipeline lives in `sh` while the ABI and device behaviour are still being validated. Once stable it can be split into a dedicated `sherylynn/wlroots` fork without changing runtime contracts.

Do not silently move this work to wlroots master: backend/output interfaces are unstable.

## Implemented stages

### Stage A — Anland transport probe

`prepare_transport.sh` reconstructs the exact Anland 5.13 producer transport from the pinned Weston-Anland implementation and builds `/opt/newhome-wayland/anland-transport/bin/anland-probe`.

It reports:

- Android screen width/height/refresh;
- consumer attach/detach;
- every Anland DMA-BUF fd/stride/format/modifier/offset;
- Android pointer/keyboard/touch events.

### Stage B1 — wlroots 0.18 output/reconnect

`apply_stage1_018.py` targets the actual wlroots 0.18 ABI:

- `WLR_BACKENDS=anland`;
- `wl_display *` backend lifecycle;
- `ANLAND-1` output with Android's real mode;
- fallback/reconnect tracking;
- wlroots output enable/new-output lifecycle.

### Stage B2 — input

`apply_stage2_input.py` maps Anland `InputEvent` into wlroots devices:

- absolute/relative pointer motion;
- buttons + wheel axes;
- keyboard evdev keycodes;
- multi-touch down/up/motion/frame;
- reconnect-safe input fd attachment.

The build pipeline removes newer-than-0.18 pointer fields so the generated code stays pinned to Debian 13's ABI.

### Stage B3 — GPU-only DMA-BUF presentation

Implemented by `apply_stage3_presentation.py` plus `apply_stage3_018_fixups.py`.

The first direct implementation intentionally does **not** replace Labwc's allocator with Anland consumer-owned buffers. Instead it uses a backend-local surfaceless EGL/GLES2 presenter:

```text
Android buffer-ready eventfd
        |
        v
wlroots frame event
        |
        v
Labwc renders normal GBM DMA-BUF
        |
        v
wlr_output commit
        |
        +--> import source DMA-BUF as EGLImage/texture
        |
        +--> import selected Anland DMA-BUF as EGLImage/FBO
        |
        v
GPU-only fullscreen GLES blit
        |
      glFinish
        |
 trigger_refresh()
        |
        v
Android consumer / Surface
```

Important properties:

- **no CPU framebuffer readback or memcpy/upload**;
- backend exposes `ANLAND_DRM_DEVICE` through wlroots `get_drm_fd()` so Labwc can create a GLES2 renderer + GBM allocator;
- default render node is `/dev/dri/renderD128`;
- Android owns DMA-BUF rotation; wlroots only emits a new frame after Anland's `buffer_ready` eventfd fires;
- the first successful `GPU blit -> trigger_refresh()` is logged explicitly for smoke testing;
- Stage3 currently uses `glFinish` as a conservative synchronization barrier. Native-fence/explicit-sync is a later optimization.

This is **GPU-only blit**, not direct scanout. A future optimization may teach the wlroots allocator to hand Anland consumer buffers directly to Labwc and remove the last GPU blit.

## Build

Inside the Debian chroot:

```bash
bash /root/sh/termux/chroot/wayland/wlroots-anland/build_direct_backend.sh
```

The builder:

1. fetches the exact Debian `wlroots_0.18.2-3.dsc` source;
2. applies the wlroots-0.18-specific output/reconnect overlay;
3. applies input mapping;
4. vendors the pinned Anland 5.13 producer transport;
5. applies Stage3 GPU DMA-BUF presentation;
6. exposes `/dev/dri/renderD128` through `get_drm_fd()`;
7. links EGL/GLES2 explicitly;
8. installs only under `/opt/newhome-wayland/wlroots-anland`.

It never overwrites Debian's system wlroots.

Successful compilation creates:

```text
/opt/newhome-wayland/wlroots-anland.built
```

but deliberately removes/does not create:

```text
/opt/newhome-wayland/wlroots-anland.ready
```

so `NEWHOME_WAYLAND_MODE=auto` continues using the Weston fallback until the phone itself validates Stage3.

## Device smoke test and activation

With the Anland daemon running and Android `Anland Termux` Activity open:

```bash
bash /root/sh/termux/chroot/wayland/wlroots-anland/validate_direct_backend.sh
```

The smoke test requires all of these before it passes automatically:

- render node opened successfully;
- wlroots Anland backend/output started;
- Android consumer entered ready state;
- surfaceless EGL/GLES DMA-BUF presenter initialized;
- **at least one real frame** completed GPU blit + `trigger_refresh()`;
- no non-DMA-BUF source, EGL import failure, incomplete destination FBO, buffer-ready error, or output presentation failure.

Even then it does **not** create `.ready`, because logs cannot prove colors/orientation/Android Surface visibility.

After visually confirming the Labwc/XFCE desktop and pointer behaviour:

```bash
bash /root/sh/termux/chroot/wayland/wlroots-anland/validate_direct_backend.sh --accept-visible
```

Only this second successful smoke run creates:

```text
/opt/newhome-wayland/wlroots-anland.ready
```

After that `NEWHOME_WAYLAND_MODE=auto` selects:

```text
Labwc -> wlroots-anland -> Anland
```

instead of Weston nested mode.

## Recovery / A-B mode

The bootstrap remains available intentionally:

```text
NEWHOME_WAYLAND_MODE=nested
Labwc -> wlroots Wayland backend -> Weston-Anland -> Anland
```

and direct can be forced only after validation:

```text
NEWHOME_WAYLAND_MODE=direct
Labwc -> wlroots-anland -> Anland
```

If a direct regression occurs, remove the ready marker and `auto` immediately returns to nested mode:

```bash
rm -f /opt/newhome-wayland/wlroots-anland.ready
```

The existing X11 / Termux:X11 profile remains independent and is not replaced.

When noVNC sends an RFB desktop-size request while this profile is active,
`win-git/xfce4-scaling.sh` routes it to `../anland_remote_resize.sh`. The helper
updates Anland's official `custom_width` / `custom_height` preferences and
reconnects Anland, Weston and Labwc without unmounting or restarting the Debian
container. Repeated requests for the already-active size are ignored so an
XWayland/noVNC reconnect cannot create a resize loop.

## References

1. `lfdevs/weston` Anland backend is authoritative for the Anland 5.13 producer protocol, reconnect behaviour, buffer-ready cadence, consumer DMA-BUF metadata and `trigger_refresh()` semantics.
2. `Xtr126/wlroots-android-bridge` / `labwc-android` demonstrates that a wlroots GLES/Vulkan compositor can stay GPU-only through Android presentation. Its Android allocator/transport is different, so it is a design reference rather than copied wholesale.

## Performance terminology

For this project:

- **CPU copy path**: framebuffer mapped/read back/copied by CPU — not acceptable.
- **GPU-only blit**: current Stage3; one GPU copy/composition from wlroots GBM buffer into Anland consumer DMA-BUF — acceptable first direct backend.
- **direct render into consumer buffer**: future allocator optimization; removes the Stage3 GPU blit.
- **direct scanout**: only use this term if the resulting buffer can actually bypass compositor copies and be presented directly; current Stage3 must not be described this way.
