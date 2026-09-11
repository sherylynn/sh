#!/bin/bash
set -u

TRAY_SCRIPT=/root/sh/win-git/xfce_display_tray.py
LOG_FILE=/tmp/xfce-display-tray.log

trap 'exit 0' INT TERM

while pgrep -x xfce4-panel >/dev/null 2>&1; do
    /usr/bin/python3 "$TRAY_SCRIPT" >>"$LOG_FILE" 2>&1
    rc=$?

    # A normal exit comes from the explicit "退出显示托盘" menu item.  Signal
    # exits and crashes are restarted so panel/session reloads do not leave a
    # stale, non-clickable legacy tray image behind.
    (( rc == 0 )) && exit 0
    sleep 2
done
