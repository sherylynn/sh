#!/bin/sh
# Labwc/Anland 会话的 XFCE 用户层。此文件由安装器复制到 Labwc 配置目录。

/bin/bash /root/sh/termux/chroot/wayland/anland_resume_watchdog.sh \
    >/dev/null 2>&1 &

# 这里由 Labwc 启动，WAYLAND_DISPLAY 已指向内层 compositor；比会话脚本
# 提前猜测 socket 就绪时机更可靠，direct/nested 都动态识别实际输出名。
(
    scale=$(head -n 1 /root/.config/newhome-wayland-output-scale 2>/dev/null || echo 2)
    case "$scale" in 1|2|3) ;; *) scale=2 ;; esac
    for _ in $(seq 1 50); do
        output=$(wlr-randr 2>/dev/null | awk '/^[^[:space:]]/ {print $1; exit}')
        if [ -n "$output" ] && wlr-randr --output "$output" --scale "$scale"; then
            printf '已恢复 %s 输出缩放: %sx\n' "$output" "$scale"
            exit 0
        fi
        sleep 0.1
    done
    printf '无法恢复 Wayland 输出缩放: %sx\n' "$scale" >&2
) >/tmp/newhome-wayland-output-scale.log 2>&1 &

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
(DISPLAY="${DISPLAY:-:0}" xset q >/dev/null 2>&1 || true)
env GDK_BACKEND=x11 python3 /root/sh/win-git/xfce_display_tray.py \
    >/tmp/newhome-wayland-tray.log 2>&1 &

# DevSpace / Cloudflare 控制托盘与显示托盘同样通过 Ayatana
# StatusNotifier 暴露给 XFCE 面板。状态采集全部走 devspace.sh states：
# DevSpace 运行状态、cloudflared 进程以及 Tunnel 是否真正连接 Cloudflare
# 边缘节点分开显示，避免“进程还在但公网已 530”时误报正常。
if [ -x /root/sh/win-git/devspace_tray_watchdog.sh ]; then
    env GDK_BACKEND=x11 DISPLAY="${DISPLAY:-:0}" \
        /root/sh/win-git/devspace_tray_watchdog.sh \
        >/tmp/newhome-devspace-tray.log 2>&1 &
fi
