#!/bin/bash
set -u

TRAY_SCRIPT=/root/sh/win-git/xfce_display_tray.py
LOG_FILE=/tmp/xfce-display-tray.log

# 该托盘的 GTK 菜单仍需 XWayland；indicator 图标则通过
# StatusNotifier 交给 Wayland XFCE 面板，避免 GTK 选到不可用的 display。
export GDK_BACKEND=x11
export DISPLAY="${DISPLAY:-:1}"
export XAUTHORITY="${XAUTHORITY:-/root/.Xauthority}"

trap 'exit 0' INT TERM

# Labwc 按需启动 XWayland。先发起一次轻量 X11 连接，再创建
# GTK 菜单，否则托盘会在 X socket 出现前反复崩溃。
for _xwayland_wait in 1 2 3 4 5; do
    xset q >/dev/null 2>&1 && break
    sleep 1
done

while pgrep -x xfce4-panel >/dev/null 2>&1; do
    /usr/bin/python3 "$TRAY_SCRIPT" >>"$LOG_FILE" 2>&1
    rc=$?

    # A normal exit comes from the explicit "退出显示托盘" menu item.  Signal
    # exits and crashes are restarted so panel/session reloads do not leave a
    # stale, non-clickable legacy tray image behind.
    (( rc == 0 )) && exit 0
    sleep 2
done
