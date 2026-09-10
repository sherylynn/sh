#!/bin/bash
set -Eeuo pipefail

if (( EUID != 0 )); then
    exec sudo -E bash "$0" "$@"
fi

SCALING_SCRIPT=/root/sh/win-git/xfce4-scaling.sh
RESIZE_SOURCE=/root/sh/win-git/x11vnc_remote_resize.c
RESIZE_LIBRARY=/root/.local/lib/x11vnc_remote_resize.so
AUTOSTART_DIR=/root/.config/autostart
RESIZE_BUILD=""

cleanup() {
    [ -z "$RESIZE_BUILD" ] || rm -f "$RESIZE_BUILD"
}
trap cleanup EXIT

# Audio/ALSA/PulseAudio integration for all chroot applications.
bash /root/sh/debian/newhome_mic_bridge_setup.sh

# The display preset launcher uses a native mouse-driven Zenity dialog.
apt-get install -y zenity libnotify-bin x11vnc gcc binutils libvncserver-dev
chmod 0755 "$SCALING_SCRIPT"
if [ ! -f "$RESIZE_SOURCE" ]; then
    echo "缺少 noVNC 远程分辨率适配源码：$RESIZE_SOURCE" >&2
    exit 1
fi
mkdir -p "$(dirname "$RESIZE_LIBRARY")"
RESIZE_BUILD=$(mktemp "${RESIZE_LIBRARY}.new.XXXXXX")
gcc -shared -fPIC -O2 -Wall -Wextra -Werror \
    -o "$RESIZE_BUILD" "$RESIZE_SOURCE" -ldl -pthread
if ! readelf -Ws "$RESIZE_BUILD" | grep -q '[[:space:]]rfbGetScreen$'; then
    echo "noVNC 远程分辨率适配库校验失败：未导出 rfbGetScreen" >&2
    exit 1
fi
chmod 0755 "$RESIZE_BUILD"
mv -f "$RESIZE_BUILD" "$RESIZE_LIBRARY"
RESIZE_BUILD=""
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/xfce-display-presets-panel.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Install XFCE Display Presets Button
Comment=Add the Termux:X11 resolution and scaling presets beside the system tray
Exec=$SCALING_SCRIPT --install-panel-launcher-wait
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=XFCE;
EOF
chmod 0644 "$AUTOSTART_DIR/xfce-display-presets-panel.desktop"

echo "Termux chroot 桌面集成完成：按需麦克风、XFCE 显示按钮和 noVNC 远程调整大小已启用。"
