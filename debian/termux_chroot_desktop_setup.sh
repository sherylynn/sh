#!/bin/bash
set -Eeuo pipefail

if (( EUID != 0 )); then
    exec sudo -E bash "$0" "$@"
fi

SCALING_SCRIPT=/root/sh/win-git/xfce4-scaling.sh
AUTOSTART_DIR=/root/.config/autostart

# Audio/ALSA/PulseAudio integration for all chroot applications.
bash /root/sh/debian/newhome_mic_bridge_setup.sh

# The display preset launcher uses a native mouse-driven Zenity dialog.
apt-get install -y zenity libnotify-bin
chmod 0755 "$SCALING_SCRIPT"
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

echo "Termux chroot 桌面集成完成：按需麦克风和 XFCE 显示预设按钮将在登录时启用。"
