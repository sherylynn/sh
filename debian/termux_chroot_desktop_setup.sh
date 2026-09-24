#!/bin/bash
set -Eeuo pipefail

if (( EUID != 0 )); then
    exec sudo -E bash "$0" "$@"
fi

SCALING_SCRIPT=/root/sh/win-git/xfce4-scaling.sh
NEWHOME_REPO=${NEWHOME_REPO:-/root/newhome}
CLIPBOARD_BRIDGE=/root/sh/termux/chroot/newhome_clipboard_bridge.py
CAMERA_BRIDGE=/root/sh/termux/chroot/newhome_camera_bridge.sh
DISABLE_AYATANA=/root/sh/win-git/disable_ayatana_xfce_autostart.sh
AUTOSTART_DIR=/root/.config/autostart
LEGACY_DISPLAY_TRAY_AUTOSTART=$AUTOSTART_DIR/xfce-display-tray.desktop
LEGACY_DEVSPACE_AUTOSTART=$AUTOSTART_DIR/devspace-tray.desktop
CLIPBOARD_AUTOSTART_FILE=$AUTOSTART_DIR/newhome-clipboard-bridge.desktop
CAMERA_AUTOSTART_FILE=$AUTOSTART_DIR/newhome-camera-bridge.desktop
LEGACY_AUTOSTART_FILE=$AUTOSTART_DIR/xfce-display-presets-panel.desktop
LEGACY_DISPLAY_DESKTOP_FILE=/root/Desktop/newhome-display-settings.desktop

install_newhome_linux() {
    # NewHome Linux is built from the NewHome repository. Always install it before
    # configuring XFCE so a fresh/redeployed chroot cannot keep running an old tray.
    if [ -d "$NEWHOME_REPO/.git" ]; then
        git -C "$NEWHOME_REPO" pull --ff-only || \
            echo "警告：$NEWHOME_REPO 无法快进更新，将使用当前工作树构建 NewHome Linux。" >&2
    else
        rm -rf "$NEWHOME_REPO"
        git clone https://github.com/sherylynn/newhome.git "$NEWHOME_REPO"
    fi

    (
        cd "$NEWHOME_REPO/linux"
        ./scripts/build-deb.sh
        latest_deb=$(ls -1t dist/newhome-linux_*_all.deb | head -n 1)
        apt-get install -y "./$latest_deb"
    )
}

install_newhome_linux

# Audio/ALSA/PulseAudio integration for all chroot applications.
bash /root/sh/debian/newhome_mic_bridge_setup.sh

# Desktop integration dependencies. xclip is the X11 clipboard endpoint shared
# by local applications, x11vnc/noVNC and the NewHome Android clipboard bridge.
# PipeWire is used only for the Linux video-source graph. Linux applications still
# use PulseAudio for compatibility, but final speaker playback is now forwarded by
# Termux to NewHome's Android AudioTrack endpoint on 127.0.0.1:4716.
apt-get install -y \
    zenity libnotify-bin python3 python3-gi gir1.2-gtk-3.0 \
    x11vnc xclip gcc binutils libvncserver-dev \
    build-essential pkg-config pipewire pipewire-bin wireplumber libpipewire-0.3-dev \
    gstreamer1.0-tools gstreamer1.0-pipewire \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good
chmod 0755 "$SCALING_SCRIPT" "$CLIPBOARD_BRIDGE" "$CAMERA_BRIDGE" "$DISABLE_AYATANA"
bash /root/sh/win-git/build_x11vnc_remote_resize.sh
mkdir -p "$AUTOSTART_DIR"
bash "$DISABLE_AYATANA"
# Resolution/scaling controls now live inside the persistent NewHome Linux tray.
# Remove the old independent display tray so there is one owner for this UI.
rm -f "$LEGACY_DISPLAY_TRAY_AUTOSTART" "$LEGACY_DISPLAY_DESKTOP_FILE"
pkill -f '^/bin/bash /root/sh/win-git/xfce_display_tray_watchdog.sh$' 2>/dev/null || true
pkill -f '^python3 /root/sh/win-git/xfce_display_tray.py$' 2>/dev/null || true

# DevSpace 管理已并入 NewHome Linux，清理旧独立托盘入口。
rm -f "$LEGACY_DEVSPACE_AUTOSTART"
pkill -f '^/bin/bash /root/sh/win-git/devspace_tray_watchdog.sh$' 2>/dev/null || true
pkill -f '^python3 /root/sh/win-git/devspace_tray.py$' 2>/dev/null || true

# 不再创建独立“显示设置”桌面入口；分辨率/缩放统一由 NewHome 托盘提供。
rm -f "$LEGACY_DISPLAY_DESKTOP_FILE"

cat > "$CLIPBOARD_AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=NewHome Clipboard Bridge
Comment=Synchronize Android, chroot X11 and VNC text clipboards
Exec=/usr/bin/python3 $CLIPBOARD_BRIDGE
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=XFCE;
EOF
chmod 0644 "$CLIPBOARD_AUTOSTART_FILE"

cat > "$CAMERA_AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=NewHome Camera Bridge
Comment=Expose Android Camera2 as a chroot PipeWire Video/Source
Exec=/bin/bash $CAMERA_BRIDGE start
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=XFCE;
EOF
chmod 0644 "$CAMERA_AUTOSTART_FILE"
rm -f "$LEGACY_AUTOSTART_FILE"

# Migrate the old panel Launcher to the real tray icon. This only removes our own item.
DISPLAY=${DISPLAY:-:1.0} "$SCALING_SCRIPT" --remove-panel-launcher || true

# server_configure may run while XFCE is already open. Start integrations immediately as well
# as installing next-login autostart entries. The clipboard daemon has its own flock lock and
# the camera helper has a pidfile, so duplicate startup requests are harmless.
if pgrep -x xfce4-panel >/dev/null 2>&1; then
    # NewHome daemon owns the display menu. Restart it after package upgrades so the
    # running tray always matches the just-installed package.
    pkill -f '^/usr/bin/python3 /usr/bin/newhome-linux-daemon$' 2>/dev/null || true
    nohup setsid env DISPLAY=${DISPLAY:-:1.0} /usr/bin/python3 /usr/bin/newhome-linux-daemon \
        </dev/null >/tmp/newhome-linux-daemon.log 2>&1 &
    nohup setsid env DISPLAY=${DISPLAY:-:1.0} /usr/bin/python3 "$CLIPBOARD_BRIDGE" \
        </dev/null >/tmp/newhome-clipboard-bridge-start.log 2>&1 &
    nohup setsid /bin/bash "$CAMERA_BRIDGE" start \
        </dev/null >/tmp/newhome-camera-bridge-start.log 2>&1 &
fi

echo "Termux chroot 桌面集成完成：已安装/更新 NewHome Linux，分辨率与缩放已合并进 NewHome 托盘；按需麦克风、Android/X11/VNC 剪贴板、Android Camera2→PipeWire 摄像头和 noVNC 远程调整大小已启用。"
