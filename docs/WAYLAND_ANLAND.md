# Anland + Labwc Wayland profile

This document is the architecture contract for the experimental Wayland profile. The existing Termux:X11 profile remains the stable default and must not be removed or silently changed while this profile is being developed.

## Target architecture

```text
XFCE user experience
  xfce4-panel / Thunar / xfce4-terminal / xfce4-notifyd / xfsettingsd
                              |
                            Labwc
                              |
                       wlroots 0.18.2
                              |
                  NewHome Anland backend
                              |
                 Anland Termux 5.13.3
                              |
                       Android Surface
```

Labwc owns window-management policy. wlroots owns renderer/input/output abstractions. Our Android-specific work belongs in a wlroots Anland backend, not in Labwc and not in the XFCE components.

## Version and fork policy

### Anland

Pin the Android consumer and Termux daemon to upstream `lfdevs/anland-termux` **5.13.3**.

Do **not** fork Anland for the first implementation. The Anland Android application and daemon define the display-consumer side and private producer protocol. Keeping these upstream makes it possible to compare our producer against the upstream Weston/KWin producers and avoids maintaining Android code unnecessarily.

- GitHub/official Termux: `AnlandTermux-5.13.3.apk`
- F-Droid/other Termux variants: `AnlandTermux-5.13.3-compatible.apk` plus `anland-compatible`
- Termux daemon: `anland_5.13.3_aarch64.deb`

Upgrade Anland only deliberately. The Android APK, Termux daemon and our wlroots producer must agree on the Anland protocol.

### Labwc / wlroots

Debian 13/trixie is the first target:

- Labwc: **0.8.3**
- wlroots: **0.18.2-3** Debian package / **0.18.2** upstream ABI

Do not fork Labwc initially. Labwc already uses `wlr_backend_autocreate()` and should not contain Android-specific display code.

Our maintained component is a patch/build of **wlroots 0.18.2**. During development it lives under this `sh` repository so the build, deployment and ABI pin are versioned together with the chroot orchestration. If the backend becomes stable and useful independently, move the patch to a dedicated `sherylynn/wlroots` fork later. That is a packaging/maintenance decision, not an architecture requirement.

## Current bootstrap architecture

Until the direct wlroots backend is complete, `NEWHOME_WAYLAND_MODE=auto` falls back to:

```text
XFCE components
      |
    Labwc
      |
wlroots Wayland backend
      |
Weston 14 Anland backend
      |
Anland 5.13.3
      |
Android
```

Weston is only a temporary display transport in this mode. It uses kiosk shell so the nested Labwc surface occupies the display. The user-facing compositor remains Labwc.

This mode is for bringing up and validating:

- Anland daemon / Android Surface bridge
- KGSL Freedreno/Turnip rendering
- Labwc behaviour
- XFCE panel, Thunar, terminal and notifications
- XWayland compatibility

It is **not** the final performance architecture because there is an extra compositor layer.

## Direct backend contract

The direct backend must make the following command possible without Weston:

```bash
ANLAND_SOCKET=/tmp/anland/display_daemon.sock \
WLR_BACKENDS=anland \
labwc -C /root/.config/newhome-labwc
```

The first deployment location is:

```text
/opt/newhome-wayland/wlroots-anland/
  lib/
  share/

/opt/newhome-wayland/wlroots-anland.ready
```

`start_labwc_anland.sh` detects that marker and library directory. `auto` then switches from nested bootstrap to direct mode automatically, so the tray and NewHome restart protocol do not need another migration.

## Backend implementation responsibilities

The wlroots Anland backend is responsible for the display/input boundary only:

- connect/reconnect to the Anland display-daemon socket;
- create one `wlr_output` from Android screen information;
- wrap/import the consumer-owned DMA-BUF set;
- render/present the selected DMA-BUF without a CPU framebuffer copy;
- pass acquire/release fences correctly;
- emit frame/presentation timing;
- update output mode when Android resolution changes;
- translate Android pointer, keyboard and touch events into wlroots input devices/events;
- survive Android consumer reconnect where the Anland protocol permits it.

Do not put XFCE policy, clipboard history, desktop shortcuts or Android application lifecycle policy into this backend.

The main technical risk is buffer ownership. Anland's consumer supplies the output DMA-BUFs, while normal wlroots compositors commonly render through a wlroots-owned allocator/swapchain. The direct implementation must adapt those externally supplied DMA-BUFs to the wlroots 0.18 renderer/output path instead of copying pixels through a second software buffer.

The upstream Weston Anland backend is the reference for the Anland producer protocol and externally supplied DMA-BUF lifecycle. `Xtr126/wlroots-android-bridge`/`labwc-android` is useful as a reference for wlroots/Android buffer integration, but it uses a different Android bridge and must not replace the Anland protocol in this project.

## Runtime profiles

Stable X11 profile:

```bash
bash ~/sh/termux/chroot/termux_all_in_one.sh start
```

Wayland profile:

```bash
bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh start
```

Install/bootstrap the pinned stack:

```bash
bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh install
```

Force current bootstrap mode:

```bash
NEWHOME_WAYLAND_MODE=nested bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh start
```

Force direct mode once the backend is installed:

```bash
NEWHOME_WAYLAND_MODE=direct bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh start
```

## Tray / NewHome lifecycle

The existing NewHome privileged bridge remains the only chroot restart control plane.

```text
chroot tray
   -> @newhome_control_v1
      -> NewHome
         -> foreground Termux through InternalAdbShell
         -> NewHome-owned root process
         -> execute selected profile as Termux UID
         -> foreground selected Android display Activity
```

White-listed requests:

- `RESTART` / `RESTART X11`: stable X11 profile
- `RESTART WAYLAND`: Anland/Labwc profile

No command files, watchdogs or clipboard control messages may be reintroduced.

For Wayland restart NewHome launches `com.anland.termux/.MainActivity` after the Termux-side orchestration succeeds. For X11 it launches the existing Termux:X11 Activity.

## Shared `/tmp`

The existing chroot mount configuration already binds Termux `$PREFIX/tmp` to chroot `/tmp`. This is intentional and required because the Termux daemon exposes:

```text
$PREFIX/tmp/anland/display_daemon.sock
```

and the same socket appears inside chroot as:

```text
/tmp/anland/display_daemon.sock
```

Do not create a second socket relay merely to cross the chroot boundary.

## GPU path

For the SM8750/Adreno environment use the Anland/Mesa KGSL route:

```bash
MESA_LOADER_DRIVER_OVERRIDE=kgsl
TURNIP_KMD=kgsl
GALLIUM_DRIVER=freedreno
FD_FORCE_KGSL=1
XWAYLAND_FORCE_KGSL_SURFACELESS=1
ANLAND_DRM_DEVICE=/dev/dri/renderD128
```

The installed Mesa must include the KGSL Wayland/surfaceless and DMA-BUF fixes required by the current Anland stack. Do not interpret software-rendered Weston/Labwc results as a Wayland-vs-X11 performance comparison.

## Validation rule

A code commit or successful package install is not a runtime validation. The direct backend is considered usable only after the physical device demonstrates:

1. Anland Android Activity displays Labwc directly with no Weston process;
2. renderer reports Freedreno/Turnip rather than llvmpipe;
3. mouse, keyboard and touch survive reconnect;
4. XWayland applications open correctly;
5. Android resolution changes propagate to `wlr_output`/Labwc;
6. repeated X11 -> Wayland -> X11 tray switches succeed;
7. idle CPU/GPU, frame pacing and high-resolution interaction are measured against the current Termux:X11 profile.
