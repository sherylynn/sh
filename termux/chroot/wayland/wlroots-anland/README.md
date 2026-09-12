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

The only component that needs Android display integration is wlroots. During development the patch/build pipeline lives in `sh` so the ABI pin, deployment and chroot lifecycle stay versioned together. Once stable, it can be split into a dedicated `sherylynn/wlroots` fork without changing the runtime contract.

## ABI pin

Target exactly:

- Debian 13/trixie
- Labwc 0.8.3
- wlroots upstream 0.18.2 / Debian 0.18.2-3 ABI
- Anland 5.13.3 transport

Do not silently build against wlroots master. wlroots backend/output interfaces are unstable.

## Stages

### Stage A — transport probe

`prepare_transport.sh` reconstructs the current Anland 5.13 producer transport from the pinned `lfdevs/weston` Debian patch series and builds a standalone probe. This lets us validate the daemon protocol, screen metadata, DMA-BUF descriptors and reconnect behaviour independently of Labwc/wlroots.

Inside the running chroot:

```bash
/root/sh/termux/chroot/wayland/wlroots-anland/prepare_transport.sh
/opt/newhome-wayland/anland-transport/bin/anland-probe
```

The Android `Anland Termux` Activity should be open while testing if DMA-BUFs are expected.

### Stage B — wlroots backend

The backend implementation is built against wlroots 0.18.2 and reuses the exact same vendored Anland transport. It must provide one wlroots output and Android pointer/keyboard/touch devices, import the consumer-owned DMA-BUF set, and present without CPU pixel copies.

The backend is considered installed only when:

```text
/opt/newhome-wayland/wlroots-anland/lib/
/opt/newhome-wayland/wlroots-anland.ready
```

exist. `start_labwc_anland.sh` then selects the direct path automatically.

### Stage C — remove bootstrap from normal use

Only after device validation succeeds do we make direct mode the normal path. The Weston bootstrap remains available as `NEWHOME_WAYLAND_MODE=nested` for recovery and A/B comparisons.

## Reference implementations

Two references serve different purposes and must not be mixed up:

1. `lfdevs/weston` Anland backend is authoritative for the **Anland 5.13 producer protocol**, reconnect behaviour, DMA-BUF metadata and fence channel.
2. `Xtr126/wlroots-android-bridge` / `labwc-android` is useful for **wlroots Android buffer/output integration patterns**, but its Android transport is not Anland and is not adopted here.

## Zero-copy definition

For this project, "zero-copy" means no CPU framebuffer readback/upload between Labwc/wlroots and Android. A GPU-only render into a DMA-BUF later queued by Anland is acceptable. If an intermediate GPU blit is temporarily required, logs/docs must call that out explicitly; it must not be described as direct scanout.
