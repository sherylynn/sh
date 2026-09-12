# NewHome / Anland / Labwc Wayland profile

## Target architecture

```text
XFCE user layer
  xfce4-panel / Thunar / xfce4-terminal / xfsettingsd / xfce4-notifyd
                       |
                     Labwc
                       |
                  wlroots 0.18
                       |
               Anland backend
                       |
              Anland Termux daemon
                       |
             Anland Android Activity
                       |
                Android Surface
```

The existing X11 profile remains the stable default and is not removed:

```text
XFCE -> X11 -> Termux:X11 -> x11vnc/noVNC
```

Wayland is a parallel profile, not an in-place migration.

## Version policy

Pin the first implementation to:

- Android/Termux Anland: upstream `lfdevs/anland-termux` **5.13.3**
- Debian: **13 / trixie**
- Labwc: Debian package **0.8.3**
- wlroots ABI target: Debian **0.18.2-3**

Do **not** fork Anland for the first implementation. The Android consumer and
Termux daemon stay on upstream 5.13.3. The component that needs project-owned
changes is wlroots, because Labwc delegates display/input backends to wlroots.

During development the wlroots patch/build pipeline lives under:

```text
termux/chroot/wayland/wlroots-anland/
```

Once the backend is stable on the device it can be moved to a dedicated
`sherylynn/wlroots` fork without changing the runtime/profile protocol.

## Two Wayland modes

### `nested` bootstrap

Immediately testable with upstream Anland 5.13.3 packages:

```text
XFCE components -> Labwc -> wlroots Wayland backend
                 -> patched Weston Anland backend -> Anland -> Android
```

Weston is only the transport compositor. It is not the user desktop.

### `direct` final target

```text
XFCE components -> Labwc -> patched wlroots Anland backend -> Anland -> Android
```

`auto` mode uses direct only when:

```text
/opt/newhome-wayland/wlroots-anland.ready
```

exists. Otherwise it falls back to nested mode.

A successful compile creates only `.built`. `.ready` is created separately
after an on-device runtime smoke test, so a half-working backend cannot black
screen the normal `auto` path.

## Install and first test

From Termux:

```bash
cd ~/sh
git pull
bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh install
bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh doctor
NEWHOME_WAYLAND_MODE=nested bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh start
```

Install the Anland APK prepared by the installer when Android asks. The pinned
release artifacts are SHA-256 verified by `anland_versions.sh`.

The existing chroot already bind-mounts Termux `$PREFIX/tmp` to `/tmp`, so both
sides see the same Anland daemon socket:

```text
Termux: $PREFIX/tmp/anland/display_daemon.sock
chroot: /tmp/anland/display_daemon.sock
```

## Tray/profile switching

The X11 display tray has:

```text
重启 / 切换桌面
  -> 重启到 X11（Termux:X11）
  -> 重启到 Wayland（Anland + Labwc）
```

The Wayland session launches `wayland_profile_tray.py`, which can restart the
Wayland profile or switch back to X11.

Both use the same NewHome abstract Unix control socket. No command file,
watchdog or clipboard control message is involved.

Protocol:

```text
RESTART X11
RESTART WAYLAND
```

NewHome owns the outer root process, first foregrounds Termux via its internal
ADB channel, runs the selected Termux orchestration script, then foregrounds the
matching display Activity:

- X11 -> `com.termux.x11/com.termux.x11.MainActivity`
- Wayland -> `com.anland.termux/.MainActivity`

## Direct backend development contract

`prepare_transport.sh` extracts the exact Anland 5.13 producer transport from
the pinned lfdevs Weston source and builds a standalone probe.

`build_direct_backend.sh` builds against Debian wlroots 0.18.2-3 into:

```text
/opt/newhome-wayland/wlroots-anland/
```

It never replaces Debian's system wlroots package.

The first direct backend must provide:

1. one Anland output with Android width/height/refresh;
2. reconnect/fallback handling when the Android Activity disappears;
3. pointer, keyboard and touch events from Anland;
4. a GPU-only DMA-BUF render/presentation path;
5. no CPU framebuffer readback/upload;
6. a `wlr-anland-smoke` binary used by `activate_direct_backend.sh`.

Only after the device smoke test succeeds may the activation script create:

```text
/opt/newhome-wayland/wlroots-anland.ready
```

## What remains intentionally unchanged

Wayland work must not alter the stable X11 path while it is experimental:

- `termux_all_in_one.sh` remains the X11 default;
- Termux:X11/x11vnc/noVNC continue to work;
- NewHome clipboard bridge stays independent of display profile control;
- no watchdog/trigger-file restart design is allowed to return.
