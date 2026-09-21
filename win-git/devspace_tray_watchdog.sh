#!/bin/bash
set -euo pipefail

TRAY=/root/sh/win-git/devspace_tray.py
PIDFILE=/tmp/devspace-tray.pid
LOG=/tmp/devspace-tray-start.log

if [ -s "$PIDFILE" ]; then
  pid=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "$pid" ] && [ -r "/proc/$pid/cmdline" ] &&
     tr '\0' ' ' <"/proc/$pid/cmdline" | grep -Fq "$TRAY"; then
    exit 0
  fi
fi

if pgrep -f "^/usr/bin/python3 $TRAY$" >/dev/null 2>&1; then
  exit 0
fi

mkdir -p /root/.config/autostart
nohup setsid env DISPLAY="${DISPLAY:-:1.0}" /usr/bin/python3 "$TRAY" \
  </dev/null >>"$LOG" 2>&1 &
printf '%s\n' "$!" >"$PIDFILE"
