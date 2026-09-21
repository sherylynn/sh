#!/bin/bash
set -euo pipefail

config_home=${XDG_CONFIG_HOME:-${HOME:?HOME is required}/.config}
autostart_dir=$config_home/autostart
override=$autostart_dir/ayatana-indicator-application.desktop

mkdir -p "$autostart_dir"
cat >"$override" <<'EOF'
[Desktop Entry]
Type=Application
Name=Ayatana Indicator Application
Hidden=true
X-GNOME-Autostart-enabled=false
EOF
chmod 0644 "$override"

# A user-level override prevents the next XFCE autostart, but an already
# running service keeps ownership of org.kde.StatusNotifierWatcher. Release it
# gracefully so xfce4-panel's systray can claim the watcher on this startup.
pkill -TERM -f '^/usr/libexec/ayatana-indicator-application/ayatana-indicator-application-service$' 2>/dev/null || true
