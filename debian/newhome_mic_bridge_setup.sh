#!/bin/bash
set -Eeuo pipefail

if (( EUID != 0 )); then
    exec sudo -E bash "$0" "$@"
fi

BRIDGE=/root/sh/termux/newhome_mic_bridge.sh
AUTOSTART_DIR=/root/.config/autostart

apt-get install -y libasound2-plugins pulseaudio-utils python3
test -x "$BRIDGE" || chmod 0755 "$BRIDGE"

cat > /etc/asound.conf <<'EOF'
# Make ALSA-only applications (including Electron/Chromium) use Termux PulseAudio.
pcm.!default {
    type pulse
}

ctl.!default {
    type pulse
}
EOF

cat > /etc/profile.d/termux-pulse.sh <<'EOF'
# Termux PulseAudio TCP bridge shared by playback and NewHome microphone input.
export PULSE_SERVER=tcp:127.0.0.1:4713
EOF
chmod 0644 /etc/profile.d/termux-pulse.sh

if grep -q '^PULSE_SERVER=' /etc/environment 2>/dev/null; then
    sed -i 's|^PULSE_SERVER=.*|PULSE_SERVER=tcp:127.0.0.1:4713|' /etc/environment
else
    printf '%s\n' 'PULSE_SERVER=tcp:127.0.0.1:4713' >> /etc/environment
fi

mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/newhome-microphone-bridge.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=NewHome Microphone Bridge
Comment=Expose the Android microphone as the default Linux microphone on demand
Exec=$BRIDGE start
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
EOF
chmod 0644 "$AUTOSTART_DIR/newhome-microphone-bridge.desktop"

echo "NewHome Linux 麦克风桥配置完成；下次 XFCE 登录时自动启用。"
