# wlroots-anland direct backend workspace

This directory is the implementation workspace for the final direct path:

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

The existing Weston-Anland path is only a bootstrap/fallback and stays usable while this backend is developed.

## Why the backend lives here first

We do not fork Anland or Labwc for the first implementation. The Android consumer and Termux daemon stay on upstream `lfdevs/anland-termux` 5.13.3, and Debian 13's Labwc stays unmodified.

The only component that needs Android display integration is wlroots. During development the source-overlay/build pipeline lives in `sh` so the ABI pin, deployment and chroot lifecycle stay versioned together. Once stable, it can be split into a dedicated `sherylynn/wlroots` fork without changing the runtime contract.

## ABI pin

Target exactly:

- Debian 13/trixie
- Labwc 0.8.3
- wlroots upstream 0.18.2 / Debian 0.18.2-3 ABI
- Anland 5.13.3 transport

Do not silently build against wlroots master. wlroots backend/output interfaces are unstable.

## Current implementation status

### Stage A — transport probe: implemented

`prepare_transport.sh` reconstructs the current Anland 5.13 producer transport from the pinned `lfdevs/weston` Debian patch and builds a standalone probe. It validates daemon protocol, screen metadata, consumer reconnect and every DMA-BUF descriptor (`fd/stride/format/modifier/offset`).

Inside the running chroot:

```bash
bash /root/sh/termux/chroot/wayland/wlroots-anland/prepare_transport.sh
/opt/newhome-wayland/anland-transport/bin/anland-probe
```

The Android `Anland Termux` Activity must be open when probing the consumer DMA-BUF set.

### Stage B1 — wlroots output/reconnect: implemented in source overlay

`apply_stage1_overlay.py` adds an explicit `anland` wlroots backend to the pinned Debian source tree:

- `WLR_BACKENDS=anland` selection;
- Anland 5.13 daemon connection;
- real Android width/height/refresh discovery;
- `ANLAND-1` wlroots output;
- consumer fallback/reconnect tracking.

It deliberately rejects framebuffer commits. It is not a usable direct desktop by itself.

### Stage B2 — pointer/keyboard/touch: implemented in source overlay

`apply_stage2_input.py` maps the Anland `InputEvent` protocol into native wlroots input devices:

- absolute + relative pointer motion;
- mouse buttons and wheel axes;
- keyboard evdev keycodes (same semantics used by the upstream Anland Weston backend);
- multi-touch down/up/motion/frame events;
- input fd detach/re-attach across Android consumer reconnects.

### Stage B3 — consumer-owned DMA-BUF presentation: in progress

This is the remaining blocker for direct mode. The backend must import the DMA-BUF set handed over by Anland and make wlroots render/present into the consumer-selected buffer without CPU framebuffer copies.

The authoritative Weston implementation renders directly into Anland-owned renderbuffers and calls `trigger_refresh()` only after the selected buffer has been painted. wlroots normally renders into buffers obtained from its own allocator/swapchain, so the integration point has to be designed explicitly rather than pretending a normal wlroots buffer is an Anland buffer.

Two acceptable implementations are being evaluated after the device transport probe reports the actual SM8750 buffer format/modifier set:

1. **Preferred:** wrap Anland consumer DMA-BUFs as wlroots-owned render targets / allocator buffers so Labwc renders directly into the selected Android buffer.
2. **Fallback:** keep wlroots' normal GPU render target and perform a GPU-only blit into the selected Anland DMA-BUF. This avoids CPU copies but must be documented as a GPU blit, not direct scanout.

A CPU framebuffer readback/memcpy/upload path is not acceptable for the final backend.

## Build vs activation safety gate

Run the development build inside Debian chroot:

```bash
bash /root/sh/termux/chroot/wayland/wlroots-anland/build_direct_backend.sh
```

The build script obtains the exact Debian `0.18.2-3` source through its `.dsc`, applies the strict-anchor source overlays, vendors the pinned Anland transport, builds into an isolated prefix and never replaces Debian's system wlroots.

Successful B1/B2 compilation creates only:

```text
/opt/newhome-wayland/wlroots-anland.built
```

It does **not** create:

```text
/opt/newhome-wayland/wlroots-anland.ready
```

`auto` mode therefore continues to use the safe Weston bootstrap.

After B3 exists, `activate_direct_backend.sh` will run the on-device output/input/DMA-BUF smoke test. Only a successful runtime test may create `.ready`, after which:

```text
NEWHOME_WAYLAND_MODE=auto
```

selects the direct Labwc → wlroots-anland path.

## Nested profile available now

The current end-to-end test path is:

```text
XFCE components
      |
    Labwc
      |
wlroots Wayland backend
      |
Weston Anland backend
      |
 Anland 5.13.3
      |
   Android
```

Install/start from Termux:

```bash
cd ~/sh
git pull
bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh install
bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh doctor
NEWHOME_WAYLAND_MODE=nested bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh start
```

The Wayland tray can switch back to the existing Termux:X11 profile. The X11 profile remains the stable default and is not modified by these experiments.

## Reference implementations

Two references serve different purposes and must not be mixed up:

1. `lfdevs/weston` Anland backend is authoritative for the **Anland 5.13 producer protocol**, reconnect behaviour, DMA-BUF metadata and fence channel.
2. `Xtr126/wlroots-android-bridge` / `labwc-android` is useful for **wlroots Android allocator/output integration patterns**. It already demonstrates GPU-only wlroots buffers presented to Android SurfaceFlinger, but its Android transport/allocator is not Anland and is not copied wholesale here.

## Zero-copy definition

For this project, "zero-copy" means no CPU framebuffer readback/upload between Labwc/wlroots and Android. A GPU-only render into a DMA-BUF later queued by Anland is acceptable. If an intermediate GPU blit is temporarily required, logs/docs must call that out explicitly; it must not be described as direct scanout.
