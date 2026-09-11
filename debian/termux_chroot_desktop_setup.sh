#!/bin/bash
set -Eeuo pipefail

if (( EUID != 0 )); then
    exec sudo -E bash "$0" "$@"
fi

SCALING_SCRIPT=/root/sh/win-git/xfce4-scaling.sh
TRAY_SCRIPT=/root/sh/win-git/xfce_display_tray.py
AUTOSTART_DIR=/root/.config/autostart
AUTOSTART_FILE=$AUTOSTART_DIR/xfce-display-tray.desktop
LEGACY_AUTOSTART_FILE=$AUTOSTART_DIR/xfce-display-presets-panel.desktop

# Audio/ALSA/PulseAudio integration for all chroot applications.
bash /root/sh/debian/newhome_mic_bridge_setup.sh

# The display preset launcher uses a native mouse-driven Zenity dialog.
apt-get install -y zenity libnotify-bin python3-gi gir1.2-gtk-3.0 x11vnc gcc binutils libvncserver-dev
chmod 0755 "$SCALING_SCRIPT" "$TRAY_SCRIPT"
bash /root/sh/win-git/build_x11vnc_remote_resize.sh
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Termux:X11 Display Tray
Comment=Termux:X11 resolution and Linux UI scaling menu
Exec=$TRAY_SCRIPT
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=XFCE;
EOF
chmod 0644 "$AUTOSTART_FILE"
rm -f "$LEGACY_AUTOSTART_FILE"

# Migrate the old panel Launcher to the real tray icon. This only removes our own item.
DISPLAY=${DISPLAY:-:1.0} "$SCALING_SCRIPT" --remove-panel-launcher || true

# server_configure may run while XFCE is already open. Start the tray immediately as well as
# installing its next-login autostart entry; setsid keeps it independent of the installer shell.
if pgrep -x xfce4-panel >/dev/null 2>&1 &&
   ! pgrep -f '^python3 /root/sh/win-git/xfce_display_tray.py$' >/dev/null 2>&1; then
    nohup setsid env DISPLAY=${DISPLAY:-:1.0} "$TRAY_SCRIPT" \
        </dev/null >/tmp/xfce-display-tray.log 2>&1 &
fi

echo "Termux chroot 桌面集成完成：按需麦克风、XFCE 显示按钮和 noVNC 远程调整大小已启用。"
