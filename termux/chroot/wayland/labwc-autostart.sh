#!/bin/sh
# Labwc/Anland 会话的 XFCE 用户层。此文件由安装器复制到 Labwc 配置目录。

xfsettingsd --replace >/tmp/newhome-wayland-xfsettings.log 2>&1 &
xfce4-notifyd >/tmp/newhome-wayland-notify.log 2>&1 &
thunar --daemon >/tmp/newhome-wayland-thunar.log 2>&1 &

xfdesktop --disable-wm-check >/tmp/newhome-wayland-xfdesktop.log 2>&1 &
# xfdesktop 4.20 在 Labwc 下能提供桌面图标，但其黑色 background
# layer 会遮住先启动的壁纸。等它建立桌面 layer 后再用 swaybg 铺底。
(
    sleep 1
    exec swaybg -i /usr/share/backgrounds/xfce/xfce-blue.jpg -m fill
) >/tmp/newhome-wayland-swaybg.log 2>&1 &
xfce4-panel >/tmp/newhome-wayland-panel.log 2>&1 &
(
    sleep 2
    # XFCE 可能默认隐藏新注册的 StatusNotifier 项。
    xfconf-query -c xfce4-panel -p /plugins/plugin-6/hide-new-items \
        -n -t bool -s false 2>/dev/null ||
        xfconf-query -c xfce4-panel -p /plugins/plugin-6/hide-new-items \
            -s false 2>/dev/null || true
) >/tmp/newhome-wayland-panel-tray-config.log 2>&1 &

# 托盘程序优先使用 Ayatana StatusNotifier，可被原生 Wayland XFCE
# 面板看见；它会识别 Anland 并调用专用分辨率重连脚本。
(DISPLAY=:1 xset q >/dev/null 2>&1 || true)
env GDK_BACKEND=x11 python3 /root/sh/win-git/xfce_display_tray.py \
    >/tmp/newhome-wayland-tray.log 2>&1 &
