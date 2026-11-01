# NewHome camera bridge for Termux:X11 chroot

This directory is the Linux half of NewHome's phone-camera bridge. It does not use Anland as a display backend and does not change the Termux:X11 desktop path.

## Build/runtime dependencies

Debian/Ubuntu chroot:

```bash
apt install build-essential pkg-config libpipewire-0.3-dev pipewire pipewire-bin
```

`debian/termux_chroot_desktop_setup.sh` now installs these dependencies and creates an XFCE autostart entry. The helper starts a small PipeWire core only if the current chroot session does not already have one. It deliberately does **not** replace the existing Termux PulseAudio audio path.

The helper builds the bridge on first use and installs it to `/usr/local/bin/newhome-camera-pipewire`.
On current NewHome bundles the helper delegates PipeWire/WirePlumber ownership to `/usr/bin/newhome-media-runtime-recover`; this avoids camera/audio starting competing media cores and recovers stale `pipewire-0` sockets after a core crash. Older bundles keep a compatibility fallback.

The producer waits up to 60 seconds for the Android `@newhome.camera` service so an FGS rebuild can recover without restarting Linux. It logs immediately while waiting and every 5 seconds thereafter. For fault injection only, `NEWHOME_CAMERA_CONNECT_TIMEOUT_MS` can shorten that bounded wait.

## Start

After installing a NewHome APK containing `CameraBridgeService`:

```bash
cd ~/sh/termux/chroot
./newhome_camera_bridge.sh start
```

The first run opens a short NewHome permission Activity. Grant camera access once. Later starts normally return immediately to Linux. With the desktop setup applied, this helper runs automatically when XFCE starts, so Linux applications can discover the camera before they request frames.

Useful commands:

```bash
./newhome_camera_bridge.sh status
./newhome_camera_bridge.sh foreground   # debug in foreground
./newhome_camera_bridge.sh stop
```

Select another camera/requested size:

```bash
NEWHOME_CAMERA_INDEX=1 \
NEWHOME_CAMERA_WIDTH=1920 \
NEWHOME_CAMERA_HEIGHT=1080 \
./newhome_camera_bridge.sh start
```

Android chooses the exact YUV_420_888 size when available, otherwise the nearest size. The PipeWire node is named `newhome.camera` and described as `NewHome Camera`.

## Data path

`Camera2 -> ImageReader -> JNI NV21 pack -> two-slot SharedMemory -> SCM_RIGHTS -> newhome-camera-pipewire -> PipeWire Video/Source`

Only protocol messages travel through the abstract Unix socket. Video pixels remain in shared memory and are copied once into the PipeWire buffer. The Android camera is opened only while PipeWire marks the source `STREAMING`.

On current NewHome bundles the bridge follows the live XFCE session's `XDG_RUNTIME_DIR` (normally `/tmp/newhome-runtime-0`) rather than trusting an arbitrary maintenance shell environment; this prevents `XDG_RUNTIME_DIR=/tmp` from connecting to the wrong PipeWire namespace. `NEWHOME_CAMERA_RUNTIME_DIR` is the explicit diagnostic override. Older bundles without the shared media owner retain the `/run/user/<uid>` fallback. The same runtime must be visible to the PipeWire client application.

## Validation

Code/build success is not hardware validation. On the phone/chroot verify:

```bash
pw-cli ls Node | grep -A8 -B2 newhome.camera
```

Then test a PipeWire camera consumer. Check color/orientation, sustained frame delivery, camera switch/index behavior, and that Android's camera privacy indicator turns off when the consumer closes.

For an explicit X11 presentation check, avoid `autovideosink` so the selected sink is known:

```bash
gst-launch-1.0 pipewiresrc target-object=newhome.camera \
  stream-properties="props,media.type=Video,media.category=Capture,media.role=Camera" \
  ! videoconvert ! ximagesink
```

The PipeWire source must advertise `SPA_META_Header` and fill `pts`, `seq`, and
`dts_offset` for every queued frame. Without this metadata, file sinks can still
capture changing NV21 buffers while a clocked X11 video sink remains on the
initial black frame. A NewHome Activity in the background is not by itself a
failure: the Android foreground service continues to own Camera2, while the
Termux:X11 application is expected to be foreground for this test.

The design was informed by Anland's proven camera-resource architecture, but this implementation is independent and does not vendor/copy Anland or Weston GPL source.
