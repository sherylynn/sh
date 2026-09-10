#!/bin/bash
# XFCE4 高分屏缩放 / DPI 设置脚本（多屏 / 多方法版）
# 适用于 Termux chroot + termux-x11（真实 X 后端）+ VNC 监控 + 骁龙 GPU 驱动
#
# 设计目标：
#   - 提供多种「缩放实现（方法）」，哪个在你的环境能用，你自己挑。
#   - xrandr 整体缩放：让 xrandr 接管整屏（统一、GPU 加速、VNC 同步可见）。
#   - DPI + 环境变量：不依赖 xrandr，纯文本/工具包缩放（到处能用）。
#   - XFCE 全局整数缩放(Gdk/WindowScalingFactor)：屏幕分辨率保持原生(1:1)，UI 按整数倍绘制，真·视网膜最清晰，推荐。
#   - termux-x11 输出分辨率：直接改 X 服务器帧缓冲，App 在线时可即时生效。
#   - 精细调整：逐项设字体/面板/图标/光标（老方法保留）。
#   - 切换方法时会先「复位」其它机制，避免叠加导致双重缩放。

set -e

# 本脚本也会由 x11vnc 的 LD_PRELOAD 适配回调启动。该变量不能继续传给
# chroot 后的 Android/Termux 动态链接器，否则宿主 env/am 会因找不到 Debian
# 路径下的适配库而拒绝启动。
unset LD_PRELOAD LD_DEBUG

# ---------- 基准值 ----------
BASE_DPI=100

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------- 运行时探测变量 ----------
XRANDR_OUTPUT=""
XRANDR_OK=0
CURRENT_RES=""
CURRENT_W=""
CURRENT_H=""
NATIVE_W=""
NATIVE_H=""
SELECTED_SCALE=""

# ---------- 从 chroot 调用宿主 Termux:X11 偏好设置 ----------
# Debian chroot 看不到 Termux 的 /data/data/com.termux；但两边共享宿主 /proc，
# 可借正在运行的 termux-x11 进程根目录进入 Android/Termux 环境执行命令。
run_termux_x11_preference() {
    if command -v termux-x11-preference >/dev/null 2>&1; then
        timeout 10 termux-x11-preference "$@"
        return $?
    fi

    local pid host_root prefix output arg key value
    local -a extras=()
    pid=$(pgrep -f '(^|/)termux-x11([[:space:]]|$)' 2>/dev/null | head -1)
    if [ -z "$pid" ]; then
        echo -e "${RED}未找到正在运行的宿主 termux-x11 进程。${NC}" >&2
        return 1
    fi

    host_root="/proc/${pid}/root"
    prefix="/data/data/com.termux/files/usr"
    if [ ! -x "${host_root}/system/bin/am" ] || [ ! -x "${host_root}${prefix}/bin/env" ]; then
        echo -e "${RED}无法通过 ${host_root} 进入宿主 Android/Termux 环境。${NC}" >&2
        return 1
    fi

    # Android 14+ 的 companion loader 从 chroot 调用时可能静默返回 0、实际不写偏好。
    # 直接调用源码中 Receiver 使用的有序广播，并检查 result/data，杜绝假成功。
    for arg in "$@"; do
        if [[ "$arg" != *:* ]]; then
            echo -e "${RED}无效的 Termux:X11 偏好参数：${arg}${NC}" >&2
            return 1
        fi
        key=${arg%%:*}
        value=${arg#*:}
        extras+=("-e" "$key" "$value")
    done
    output=$(timeout 10 chroot "$host_root" "$prefix/bin/env" -i \
        HOME=/data/data/com.termux/files/home \
        PREFIX="$prefix" TMPDIR="$prefix/tmp" \
        PATH="$prefix/bin:/system/bin:/system/xbin" \
        /system/bin/am broadcast --user 0 \
        -a com.termux.x11.CHANGE_PREFERENCE -p com.termux.x11 \
        "${extras[@]}" 2>&1) || {
        echo "$output" >&2
        return 1
    }
    if ! grep -q 'result=\(2\|4\).*data="Done"' <<< "$output"; then
        echo "$output" >&2
        return 1
    fi
}

wait_for_x11_resolution() {
    local expected=$1 current
    for _ in {1..150}; do
        current=$(xrandr 2>/dev/null | sed -n 's/.*current \([0-9]*\) x \([0-9]*\).*/\1x\2/p' | head -1)
        [ "$current" = "$expected" ] && return 0
        sleep 0.1
    done
    echo -e "${RED}等待 X11 切换到 ${expected} 超时。${NC}" >&2
    return 1
}

# noVNC Remote Resizing 通过 RFB SetDesktopSize 传入任意浏览器视口尺寸。
# x11vnc 使用 -xrandr resize 在线更新 framebuffer；这里不能停掉 VNC，否则
# noVNC 会断线重连并再次发送 SetDesktopSize，形成关闭/重启循环。
apply_remote_resize() {
    local resolution=$1 lock_file=/tmp/xfce-remote-resize.lock
    [[ "$resolution" =~ ^[0-9]+x[0-9]+$ ]] || {
        echo "拒绝无效的远程分辨率：$resolution" >&2
        return 1
    }
    local width=${resolution%x*} height=${resolution#*x}
    (( width >= 320 && width <= 8192 && height >= 240 && height <= 8192 )) || {
        echo "远程分辨率超出允许范围：$resolution" >&2
        return 1
    }
    exec 9>"$lock_file"
    flock -n 9 || return 0

    local current
    current=$(xrandr 2>/dev/null | sed -n 's/.*current \([0-9]*\) x \([0-9]*\).*/\1x\2/p' | head -1)
    [ "$current" = "$resolution" ] && return 0

    if ! run_termux_x11_preference \
        "displayResolutionMode:custom" \
        "displayResolutionCustom:${resolution}" \
        "displayScale:100"; then
        return 1
    fi
    if ! wait_for_x11_resolution "$resolution"; then
        return 1
    fi
}

# 浏览器最大化/拖动窗口时会密集发送 SetDesktopSize。先把请求合并，连续 1 秒
# 没有新尺寸后才真正调整；所有后来者只更新 pending 文件，不会反复重启 VNC。
queue_remote_resize() {
    local resolution=$1
    local pending=/tmp/xfce-remote-resize.pending
    local worker_lock=/tmp/xfce-remote-resize.worker.lock
    local suppress_file=/tmp/xfce-remote-resize.suppress-until
    local next suppress_until=0 now

    [[ "$resolution" =~ ^[0-9]+x[0-9]+$ ]] || return 1
    now=$(date +%s)
    [ -f "$suppress_file" ] && suppress_until=$(head -n 1 "$suppress_file" 2>/dev/null || echo 0)
    if [[ "$suppress_until" =~ ^[0-9]+$ ]] && (( now < suppress_until )); then
        printf 'time=%s ignored=%s reason=manual-profile-cooldown\n' "$now" "$resolution" \
            >> /tmp/x11vnc-remote-resize.log
        return 0
    fi
    printf '%s\n' "$resolution" > "${pending}.$$"
    mv -f "${pending}.$$" "$pending"

    exec 8>"$worker_lock"
    flock -n 8 || return 0
    while true; do
        next=$(head -n 1 "$pending" 2>/dev/null || true)
        sleep 1
        [ "$next" = "$(head -n 1 "$pending" 2>/dev/null || true)" ] && break
    done
    apply_remote_resize "$next"
}

# ---------- 探测当前显示 ----------
detect_display() {
    if command -v xrandr >/dev/null 2>&1; then
        local line
        line=$(xrandr 2>/dev/null | awk '/ connected/{print; exit}')
        if [ -n "$line" ]; then
            XRANDR_OUTPUT=$(echo "$line" | awk '{print $1}')
            XRANDR_OK=1
        fi
        CURRENT_RES=$(xrandr 2>/dev/null | sed -n 's/.*current \([0-9]*\) x \([0-9]*\).*/\1x\2/p' | head -1)
    fi
    if [ -z "$CURRENT_RES" ]; then
        CURRENT_RES=$(xrandr 2>/dev/null | grep -oP '\d+x\d+' | head -1)
    fi
    if [ -n "$CURRENT_RES" ]; then
        CURRENT_W=${CURRENT_RES%x*}
        CURRENT_H=${CURRENT_RES#*x}
    fi
    # 首次探测到的分辨率记为「原生分辨率」，供复位使用
    if [ -z "$NATIVE_W" ] && [ -n "$CURRENT_W" ]; then
        NATIVE_W=$CURRENT_W
        NATIVE_H=$CURRENT_H
    fi
}

# ---------- 复位所有缩放机制 ----------
# 注意：不会改动 termux-x11 的输出分辨率（它由 App 持久保存），
# 仅复位 xrandr 缩放、Xft DPI、以及 .xsessionrc 里的环境变量块。
reset_scaling() {
    if [ "$XRANDR_OK" -eq 1 ] && [ -n "$XRANDR_OUTPUT" ]; then
        xrandr --output "$XRANDR_OUTPUT" --scale 1x1 2>/dev/null || true
    fi
    xfconf-query -c xsettings -p /Xft/DPI -s "$BASE_DPI" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gdk/WindowScalingFactor -s 1 2>/dev/null || true
    if [ -f ~/.xsessionrc ]; then
        sed -i '/# Display scaling/d; /^export GDK_SCALE=/d; /^export GDK_DPI_SCALE=/d; /^export QT_SCALE_FACTOR=/d; /^export QT_AUTO_SCREEN_SCALE_FACTOR=/d; /^export QT_FONT_DPI=/d; /^export QT_ENABLE_HIGHDPI_SCALING=/d' ~/.xsessionrc
    fi
}

# ---------- 确保 xfsettingsd 运行（把 xfconf 广播成 XSETTINGS，GTK/Qt 才真正读到） ----------
ensure_xfsettingsd() {
    if ! pgrep -x xfsettingsd >/dev/null 2>&1; then
        echo -e "${YELLOW}xfsettingsd 未运行，正在启动...${NC}"
        xfsettingsd >/dev/null 2>&1 &
        sleep 1
    fi
}

# ---------- 写入环境变量块 ----------
# $1 = 模式: neutral | dpi | gdk | qt_only
write_env() {
    local mode=$1 scale=${2:-1}
    if [ -f ~/.xsessionrc ]; then
        sed -i '/# Display scaling/d; /^export GDK_SCALE=/d; /^export GDK_DPI_SCALE=/d; /^export QT_SCALE_FACTOR=/d; /^export QT_AUTO_SCREEN_SCALE_FACTOR=/d; /^export QT_FONT_DPI=/d; /^export QT_ENABLE_HIGHDPI_SCALING=/d' ~/.xsessionrc
    fi
    case $mode in
        neutral)
            cat >> ~/.xsessionrc << EOF
# Display scaling (xrandr/neutral) ${scale}x
export GDK_SCALE=1
export GDK_DPI_SCALE=1
export QT_SCALE_FACTOR=1
export QT_AUTO_SCREEN_SCALE_FACTOR=0
EOF
            ;;
        dpi)
            # 使用 GDK_DPI_SCALE 实现 GTK 分数缩放, QT_SCALE_FACTOR 用于 Qt
            # Xft.dpi 也已设置, 用于其他传统程序
            # 设置 QT_FONT_DPI=96 来避免 Qt 程序内的字体被重复缩放
            cat >> ~/.xsessionrc << EOF
# Display scaling (dpi) ${scale}x
export GDK_SCALE=1
export GDK_DPI_SCALE=${scale}
export QT_SCALE_FACTOR=${scale}
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export QT_FONT_DPI=96
export QT_ENABLE_HIGHDPI_SCALING=1
EOF
            ;;
        gdk)
            cat >> ~/.xsessionrc << EOF
# Display scaling (gdk integer) ${scale}x
export GDK_SCALE=${scale}
export GDK_DPI_SCALE=1
export QT_SCALE_FACTOR=${scale}
export QT_AUTO_SCREEN_SCALE_FACTOR=0
EOF
            ;;
        qt_only)
            # GTK 已由 Gdk/WindowScalingFactor 处理，这里只给 Qt 新进程设缩放，避免重复
            cat >> ~/.xsessionrc << EOF
# Display scaling (qt only; GTK handled by Gdk/WindowScalingFactor) ${scale}x
export QT_SCALE_FACTOR=${scale}
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export QT_ENABLE_HIGHDPI_SCALING=0
EOF
            ;;
    esac
}

# ---------- 读取并校验缩放倍数（失败循环重试） ----------
prompt_scale() {
    while true; do
        read -p "请输入缩放倍数 (如 1.35): " val
        if [[ "$val" =~ ^[0-9]*\.?[0-9]+$ ]]; then
            echo "$val"
            return 0
        fi
        echo -e "${RED}无效的倍数，请重新输入正数（如 1.35）！${NC}"
    done
}

# ---------- 显示主菜单 ----------
show_menu() {
    detect_display
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}     XFCE4 高分屏缩放 / DPI 工具${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "当前分辨率: ${GREEN}${CURRENT_RES:-未知}${NC}   原生: ${GREEN}${NATIVE_W}x${NATIVE_H}${NC}"
    echo -e "xrandr 输出: ${GREEN}${XRANDR_OUTPUT:-无}${NC}   xrandr可用: ${GREEN}$( [ "$XRANDR_OK" -eq 1 ] && echo 是 || echo 否 )${NC}"
    echo -e "当前 Xft DPI: ${GREEN}$(xfconf-query -c xsettings -p /Xft/DPI 2>/dev/null || echo 未知)${NC}"
    echo -e "当前 WindowScalingFactor: ${GREEN}$(xfconf-query -c xsettings -p /Gdk/WindowScalingFactor 2>/dev/null || echo 1)${NC}"
    echo -e "${RED}★ termux-x11 的 displayScale 务必保持 100/native（缩小帧缓冲会上采样变糊）${NC}"
    echo ""
    echo -e "${YELLOW}请选择缩放【方法】（每种都是不同实现，挑能用的）:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} xrandr 整体缩放   ${BLUE}(让 xrandr 接管整屏，最统一，GPU加速)${NC}"
    echo -e "  ${GREEN}2)${NC} DPI + 环境变量    ${BLUE}(不依赖 xrandr，纯文本/工具包缩放)${NC}"
    echo -e "  ${GREEN}3)${NC} XFCE 全局整数缩放 ${BLUE}(Gdk/WindowScalingFactor，真·视网膜清晰，推荐)${NC}"
    echo -e "  ${GREEN}4)${NC} Termux:X11 显示预设 ${BLUE}(分辨率 + XFCE/App 缩放一起调整)${NC}"
    echo -e "  ${GREEN}5)${NC} 精细调整         ${BLUE}(逐项设字体/面板/图标/光标)${NC}"
    echo ""
    echo -e "  ${YELLOW}d)${NC} 诊断当前屏幕 & 推荐倍数"
    echo -e "  ${YELLOW}v)${NC} 查看当前设置"
    echo -e "  ${GREEN}0)${NC} 退出"
    echo ""
    echo -e "${CYAN}========================================${NC}"
}

# ---------- 方法 1：xrandr 整体缩放 ----------
apply_xrandr_scale() {
    local scale=$1
    reset_scaling
    # xrandr 是唯一的缩放源，DPI/环境变量保持中性
    xfconf-query -c xsettings -p /Xft/DPI -s "$BASE_DPI" 2>/dev/null || true
    write_env neutral "$scale"

    echo ""
    if [ "$XRANDR_OK" -eq 1 ] && [ -n "$XRANDR_OUTPUT" ]; then
        echo -e "${YELLOW}正在用 xrandr 缩放整屏 (${scale}x)...${NC}"
        xrandr --output "$XRANDR_OUTPUT" --scale "${scale}x${scale}" 2>/dev/null || {
            echo -e "${RED}xrandr --scale 执行失败，可能此后端不支持。${NC}"
            echo -e "${YELLOW}可改用方法 2（DPI）或方法 4（termux-x11 分辨率）。${NC}"
            return 1
        }
        echo -e "${GREEN}✓ xrandr 整体缩放 ${scale}x 已应用（光标/面板/所有程序一起放大）${NC}"
    else
        echo -e "${RED}未检测到可用 xrandr 输出，无法用此方法。${NC}"
        echo -e "${YELLOW}请改用方法 2 或 4。${NC}"
        return 1
    fi
    echo -e "${YELLOW}提示: 缩放档若不能整除当前分辨率会轻微发糊（用 d 诊断看清晰档）。${NC}"
}

# ---------- 方法 2：DPI + 环境变量 (分数缩放) ----------
apply_dpi_mode() {
    local scale=$1
    reset_scaling
    local dpi=$(python3 -c "print(int(${BASE_DPI} * ${scale}))")
    # 为字体和旧版应用设置 Xft.DPI
    xfconf-query -c xsettings -p /Xft/DPI -s "$dpi" 2>/dev/null || true
    # 为 GTK 和 Qt 程序设置环境变量以实现分数缩放
    write_env dpi "$scale"
    echo ""
    echo -e "${GREEN}✓ DPI 分数缩放 ${scale}x 已应用（Xft.dpi=${dpi}）${NC}"
    echo -e "${YELLOW}  - 通过 GDK_DPI_SCALE 为 GTK 程序启用分数缩放。${NC}"
    echo -e "${YELLOW}  - 通过 QT_SCALE_FACTOR 为 Qt 程序启用分数缩放。${NC}"
    update_fcitx5_classicui "$scale"
    update_wechat_desktop "$scale"
    restart_fcitx5_scaled "$scale"
    echo -e "${YELLOW}  - 注意：新设置需要重新登录或打开新终端才能对程序完全生效。${NC}"
}

# ---------- 更新 Fcitx5 Classic UI 专属缩放 ----------
update_fcitx5_classicui() {
    local scale=$1
    local font_size
    font_size=$(python3 -c "print(max(8, int(round(10 * ${scale}))))")
    local theme_dir="$HOME/.local/share/fcitx5/themes/NewHomeHighContrast"
    if [ ! -f "$theme_dir/theme.conf" ] && [ -f /usr/share/fcitx5/themes/default/theme.conf ]; then
        mkdir -p "$HOME/.local/share/fcitx5/themes"
        cp -a /usr/share/fcitx5/themes/default "$theme_dir"
        sed -i \
            -e 's/^Name=Default$/Name=NewHome High Contrast/' \
            -e 's/^Description=Default Theme$/Description=High contrast blue candidate theme/' \
            -e 's/^NormalColor=#000000$/NormalColor=#1f2937/' \
            -e 's/^BorderColor=#c0c0c0$/BorderColor=#94a3b8/g' \
            -e 's/^Color=#808080$/Color=#2563eb/g' \
            -e 's/^Color=#c0c0c0$/Color=#cbd5e1/g' \
            "$theme_dir/theme.conf"
    fi
    local config_dir="$HOME/.config/fcitx5/conf"
    local config_file="$config_dir/classicui.conf"
    mkdir -p "$config_dir"
    cat > "$config_file" <<CFG
# Generated by xfce4-scaling.sh
# Fcitx5 Classic UI is rendered by Pango/Cairo, so Qt scaling alone is not enough.
Theme=NewHomeHighContrast
DarkTheme=Default Dark
PerScreenDPI=True
Font="Sans ${font_size}"
MenuFont="Sans ${font_size}"
TrayFont="Sans Bold ${font_size}"
CFG
    echo -e "${GREEN}✓ Fcitx5 Classic UI 字体已调整为 ${font_size}pt（${scale}x）${NC}"
}
# ---------- 更新 Fcitx5 候选栏启动项 ----------
update_fcitx5_autostart() {
    local scale=$1
    local autostart_file="$HOME/.config/autostart/fcitx5.desktop"
    if [ ! -f "$autostart_file" ]; then
        echo -e "${YELLOW}未找到 Fcitx5 用户启动项，跳过候选栏缩放参数更新。${NC}"
        return 0
    fi
    sed -i -E "s|^Exec=.*|Exec=env QT_SCALE_FACTOR=${scale} QT_SCREEN_SCALE_FACTORS=*:${scale} QT_AUTO_SCREEN_SCALE_FACTOR=0 QT_ENABLE_HIGHDPI_SCALING=1 GTK_IM_MODULE=fcitx5 QT_IM_MODULE=fcitx5 XMODIFIERS=@im=fcitx5 fcitx5 -d|" "$autostart_file"
    echo -e "${GREEN}✓ Fcitx5 启动项已更新：Qt 缩放=${scale}${NC}"
}
# ---------- 更新 Electron/微信桌面启动项 ----------
update_wechat_desktop() {
    local scale=$1
    local desktop_file="/usr/share/applications/wechat.desktop"
    if [ ! -f "$desktop_file" ]; then
        echo -e "${YELLOW}未找到微信桌面启动项，跳过 Electron 缩放参数更新。${NC}"
        return 0
    fi
    sed -i -E "s|^Exec=.*|Exec=env QT_SCALE_FACTOR=${scale} QT_SCREEN_SCALE_FACTORS=*:${scale} QT_AUTO_SCREEN_SCALE_FACTOR=0 QT_ENABLE_HIGHDPI_SCALING=1 /usr/bin/wechat %U|" "$desktop_file"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    fi
    echo -e "${GREEN}✓ 微信启动项已更新：force-device-scale-factor=${scale}${NC}"
}
# ---------- 让 Fcitx5 立即应用新的候选栏缩放 ----------
restart_fcitx5_scaled() {
    local scale=$1
    update_fcitx5_autostart "$scale"
    pkill -TERM -x fcitx5 2>/dev/null || true
    sleep 1
    env QT_SCALE_FACTOR="$scale" \
        QT_SCREEN_SCALE_FACTORS="*:${scale}" \
        QT_AUTO_SCREEN_SCALE_FACTOR=0 \
        QT_ENABLE_HIGHDPI_SCALING=1 \
        GTK_IM_MODULE=fcitx5 \
        QT_IM_MODULE=fcitx5 \
        XMODIFIERS=@im=fcitx5 \
        fcitx5 -d >/dev/null 2>&1 &
}

# ---------- 恢复应用的逻辑基准尺寸 ----------
# Gdk/WindowScalingFactor 已负责 1x/2x 物理缩放；这里的逻辑尺寸不能再乘倍数，
# 否则工具栏、Thunar 图标和面板会形成双重缩放。
reset_logical_ui_sizes() {
    xfconf-query -c xsettings -p /Gtk/FontName -s "Sans 10" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "Monospace 10" 2>/dev/null || true

    # Gtk/ToolbarIconSize 是 GTK 图标尺寸枚举，不是像素；清除旧脚本写入的 24/48。
    xfconf-query -c xsettings -p /Gtk/ToolbarIconSize -r 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/IconSizes -s "" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s 0 2>/dev/null || true

    xfconf-query -c xfce4-panel -p /panels/panel-1/size -s 26 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/icon-size -s 16 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-2/size -s 48 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/title_font -s "Sans Bold 9" 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/button-icon-size -r 2>/dev/null || true

    # 清除精细缩放留下的固定像素值，让 Thunar 回到自身的缩放级别管理。
    xfconf-query -c thunar -p /default-view-icon-size -r 2>/dev/null || true
    xfconf-query -c thunar -p /compact-view-icon-size -r 2>/dev/null || true
    xfconf-query -c thunar -p /last-icon-view-zoom-level \
        -s THUNAR_ZOOM_LEVEL_100_PERCENT 2>/dev/null || true
}
# ---------- 方法 3：XFCE 全局整数缩放（真·视网膜，最清晰，推荐） ----------
# 原理：屏幕物理分辨率保持原生（termux displayScale 必须=100/native，帧缓冲与物理屏 1:1 不缩放），
#       再让 XFCE 把 UI 按整数倍绘制 → 1584x720 逻辑桌面以 3168x1440 原生渲染，
#       每个逻辑像素 = 4 物理像素，且帧缓冲与物理屏 1:1 → 清晰不糊。
# 关键：用 xfce 原生键 /Gdk/WindowScalingFactor（经 xfsettingsd 广播，已运行的 GTK3 程序也生效），
#       绝对不要再用 GDK_SCALE 环境变量（会与 WindowScalingFactor 重复放大，字体翻倍）。
apply_gdk_int() {
    local scale=$1
    local gdk=$(python3 -c "print(int(round(${scale})))")
    if [ "$gdk" -lt 1 ]; then gdk=1; fi
    if [ "$gdk" -eq 1 ]; then
        echo -e "${YELLOW}整数缩放不支持 1.25/1.5 这类分数；已按 1 处理（即不缩放）。${NC}"
        echo -e "${YELLOW}要清晰视网膜请用 2（或 3）。${NC}"
    fi
    reset_scaling
    ensure_xfsettingsd
    # XFCE 全局整数缩放：GTK3 程序 + xfce4 面板 + thunar 全部套用，已运行的程序也经 xfsettingsd 生效
    xfconf-query -c xsettings -p /Gdk/WindowScalingFactor -s "$gdk"
    # 保持干净基准 DPI：WindowScalingFactor 已负责缩放字体，不要再放大 Xft/DPI（否则字体翻倍变糊/过大）
    xfconf-query -c xsettings -p /Xft/DPI -s "$BASE_DPI"
    reset_logical_ui_sizes
    update_fcitx5_classicui "$gdk"
    # Qt 程序：用环境变量（仅影响之后启动的 Qt 程序）；GTK 已由 WindowScalingFactor 处理，故不设 GDK_SCALE
    write_env qt_only "$gdk"
    # 让面板立即套用
    xfce4-panel -r 2>/dev/null &
    echo ""
    echo -e "${GREEN}✓ XFCE 全局整数缩放 ${gdk}x 已应用${NC}"
    echo -e "${YELLOW}  - Gdk/WindowScalingFactor=${gdk}（GTK3 全局，已运行程序经 xfsettingsd 广播生效）${NC}"
    update_wechat_desktop "$gdk"
    echo -e "${YELLOW}  - 逻辑桌面缩小为 ${gdk}x，每个逻辑像素由 ${gdk}x${gdk}=$((gdk*gdk)) 个物理像素绘制 → 清晰${NC}"
    update_fcitx5_autostart "$gdk"
    restart_fcitx5_scaled "$gdk"
    echo -e "${YELLOW}  - Qt 程序设 QT_SCALE_FACTOR=${gdk}（仅影响之后启动的 Qt 程序，已运行的需重启）${NC}"
    echo -e "${RED}  - 务必确认 termux-x11 的 displayScale 为 100/native；若被改成 >100 会被拉伸变糊！${NC}"
}

# ---------- 方法 4：termux-x11 原生分辨率 ----------
apply_termux_res() {
    local scale=$1
    if [ -z "$NATIVE_W" ]; then
        echo -e "${RED}未探测到原生分辨率，无法计算。${NC}"
        return 1
    fi
    local tw=$(python3 -c "print(int(${NATIVE_W} / ${scale}))")
    local th=$(python3 -c "print(int(${NATIVE_H} / ${scale}))")
    local exact_res
    read -p "目标分辨率 [默认 ${tw}x${th}，也可输入如 1920x1080]: " exact_res
    if [ -n "$exact_res" ]; then
        if [[ ! "$exact_res" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]]; then
            echo -e "${RED}分辨率格式无效，应为 WIDTHxHEIGHT（如 1920x1080）。${NC}"
            return 1
        fi
        tw=${exact_res%x*}
        th=${exact_res#*x}
    fi
    echo ""
    echo -e "${YELLOW}此操作会把 termux-x11 分辨率改为 ${tw}x${th}（≈${scale}x 放大）。${NC}"
    echo -e "${RED}注意: 这把帧缓冲改小、由手机上采样放大 → 与「视网膜清晰」相反，会糊。视网膜请改用方法 3。${NC}"
    echo -e "${YELLOW}Termux:X11 Activity 在线时会即时改变 X framebuffer，无需重启 X。${NC}"
    read -p "确认继续? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}已取消。${NC}"
        return 0
    fi
    reset_scaling
    # custom 模式和具体尺寸必须一起设置。displayScale=100 避免 Android 端再次缩放，
    # 桌面 UI 的缩放继续由本脚本的 DPI/GDK 等方法控制，避免双重缩放。
    if run_termux_x11_preference \
        "displayResolutionMode:custom" \
        "displayResolutionCustom:${tw}x${th}" \
        "displayScale:100"; then
        echo -e "${GREEN}✓ 已设置 Termux:X11：分辨率 ${tw}x${th}，输出缩放 100%${NC}"
    else
        echo -e "${RED}设置失败。请确认 Termux:X11 App 已启动（前台或后台均可）。${NC}"
        return 1
    fi
    echo -e "${YELLOW}X 会话已在线刷新；若 Activity 未打开，命令会明确报错而不会假成功。${NC}"
}

# ---------- 方法 4 菜单：Termux:X11 分辨率 + 应用缩放预设 ----------
apply_termux_profile() {
    local resolution=$1 scale=$2

    echo ""
    echo -e "${YELLOW}正在应用显示预设：${resolution} + ${scale}x...${NC}"

    # 与 noVNC 的远程尺寸 worker 串行，避免两条路径同时修改 Termux:X11。
    exec 9>/tmp/xfce-remote-resize.lock
    flock 9
    # 本次改分辨率会让 VNC 客户端重连；短时间忽略重连自动产生的旧视口请求。
    printf '%s\n' "$(( $(date +%s) + 5 ))" > /tmp/xfce-remote-resize.suppress-until

    if ! run_termux_x11_preference \
        "displayResolutionMode:custom" \
        "displayResolutionCustom:${resolution}" \
        "displayScale:100"; then
        echo -e "${RED}Termux:X11 分辨率设置失败，未继续调整应用缩放。${NC}"
        return 1
    fi

    # 沿用方法 3 的完整适配链路：XFCE/GTK、Qt、Fcitx5/Rime 和微信保持同一倍数。
    apply_gdk_int "$scale"
    wait_for_x11_resolution "$resolution" || true
    echo -e "${GREEN}✓ 显示预设已完成：${resolution} + ${scale}x（Termux:X11 输出缩放 100%）${NC}"
}

show_termux_profiles() {
    while true; do
        echo ""
        echo -e "${YELLOW}选择 Termux:X11 显示预设:${NC}"
        echo -e "  ${GREEN}1)${NC} 1920x1080 + 1x"
        echo -e "  ${GREEN}2)${NC} 2560x1600 + 2x"
        echo -e "  ${GREEN}3)${NC} 2376x1080 + 2x"
        echo -e "  ${GREEN}0)${NC} 返回上一级"
        read -p "请输入: " profile
        case $profile in
            1) apply_termux_profile 1920x1080 1; break ;;
            2) apply_termux_profile 2560x1600 2; break ;;
            3) apply_termux_profile 2376x1080 2; break ;;
            0) return 0 ;;
            *) echo -e "${RED}无效选项！${NC}" ;;
        esac
    done
    read -p "按回车继续..."
}

# ---------- 鼠标 GUI：供 XFCE 顶栏按钮调用 ----------
show_termux_profiles_gui() {
    if ! command -v zenity >/dev/null 2>&1; then
        notify-send -u critical "显示预设" "未安装 zenity，无法打开图形选择窗口。" 2>/dev/null || true
        return 1
    fi

    local current_res current_scale choice resolution scale worker rc log_file
    current_res=$(xrandr 2>/dev/null | sed -n 's/.*current \([0-9]*\) x \([0-9]*\).*/\1x\2/p' | head -1)
    current_scale=$(xfconf-query -c xsettings -p /Gdk/WindowScalingFactor 2>/dev/null || echo 1)

    choice=$(zenity --list --radiolist \
        --title="显示预设" \
        --window-icon=preferences-desktop-display \
        --width=520 --height=300 \
        --text="当前：${current_res:-未知} + ${current_scale}x\n请选择要切换的显示配置：" \
        --column="选择" --column="预设" --column="说明" \
        TRUE  "1920x1080 + 1x" "较大桌面空间，应用保持 1x" \
        FALSE "2560x1600 + 2x" "高分辨率，XFCE/Rime/Qt 使用 2x" \
        FALSE "2376x1080 + 2x" "宽屏模式，XFCE/Rime/Qt 使用 2x" \
        --print-column=2 2>/dev/null) || return 0

    case $choice in
        "1920x1080 + 1x") resolution=1920x1080; scale=1 ;;
        "2560x1600 + 2x") resolution=2560x1600; scale=2 ;;
        "2376x1080 + 2x") resolution=2376x1080; scale=2 ;;
        *) return 0 ;;
    esac

    log_file=$(mktemp /tmp/xfce-display-profile.XXXXXX.log)
    apply_termux_profile "$resolution" "$scale" >"$log_file" 2>&1 &
    worker=$!
    while kill -0 "$worker" 2>/dev/null; do
        echo "# 正在切换到 ${resolution} + ${scale}x…"
        sleep 0.2
    done | zenity --progress --pulsate --auto-close --no-cancel \
        --title="正在应用显示预设" --window-icon=preferences-desktop-display \
        --width=430 2>/dev/null || true
    if wait "$worker"; then
        rc=0
    else
        rc=$?
    fi

    if [ "$rc" -eq 0 ]; then
        zenity --info --title="显示预设" --window-icon=preferences-desktop-display \
            --text="已切换到 ${resolution} + ${scale}x。\n\nVNC、XFCE、Rime/Fcitx5 和应用缩放已同步调整。" \
            --width=430 2>/dev/null || true
    else
        zenity --error --title="显示预设切换失败" --window-icon=preferences-desktop-display \
            --text="未能应用 ${resolution} + ${scale}x。\n\n详细日志：${log_file}" \
            --width=430 2>/dev/null || true
        return "$rc"
    fi
    rm -f "$log_file"
}

# ---------- 安装 XFCE 顶栏显示预设按钮（幂等） ----------
ensure_panel_launcher() {
    command -v xfconf-query >/dev/null 2>&1 || return 0
    pgrep -x xfce4-panel >/dev/null 2>&1 || return 0

    local item_name="xfce-display-presets.desktop"
    local script_path plugin_id max_id=0 systray_id="" id panel_id=1 inserted=0 created=0
    local plugin_dir desktop_file line
    local -a panel_plugins=() new_plugins=() set_args=()
    script_path=$(readlink -f "$0")

    # 已经存在我们的 launcher 时只刷新其入口文件，不重复添加插件。
    while read -r line; do
        if [[ "$line" =~ ^/plugins/plugin-([0-9]+)/items.*${item_name} ]]; then
            plugin_id=${BASH_REMATCH[1]}
            break
        fi
    done < <(xfconf-query -c xfce4-panel -p /plugins -lv 2>/dev/null || true)

    if [ -z "$plugin_id" ]; then
        created=1
        while read -r id; do
            [[ "$id" =~ ^[0-9]+$ ]] || continue
            (( id > max_id )) && max_id=$id
        done < <(xfconf-query -c xfce4-panel -p /plugins -l 2>/dev/null |
            sed -n 's#^/plugins/plugin-\([0-9][0-9]*\)$#\1#p')
        plugin_id=$((max_id + 1))

        # 找到系统托盘（Fcitx/Rime 图标所在插件）以及它所在的面板。
        systray_id=$(xfconf-query -c xfce4-panel -p /plugins -lv 2>/dev/null |
            sed -n 's#^/plugins/plugin-\([0-9][0-9]*\)[[:space:]]\+systray$#\1#p' | head -1)
        for id in $(seq 1 20); do
            if xfconf-query -c xfce4-panel -p "/panels/panel-${id}/plugin-ids" >/dev/null 2>&1; then
                mapfile -t panel_plugins < <(xfconf-query -c xfce4-panel \
                    -p "/panels/panel-${id}/plugin-ids" 2>/dev/null | grep -E '^[0-9]+$')
                if [ -n "$systray_id" ] && printf '%s\n' "${panel_plugins[@]}" | grep -qx "$systray_id"; then
                    panel_id=$id
                    break
                fi
            fi
        done

        new_plugins=()
        for id in "${panel_plugins[@]}"; do
            new_plugins+=("$id")
            if [ "$id" = "$systray_id" ]; then
                new_plugins+=("$plugin_id")
                inserted=1
            fi
        done
        [ "$inserted" -eq 1 ] || new_plugins+=("$plugin_id")

        xfconf-query -c xfce4-panel -p "/plugins/plugin-${plugin_id}" \
            -n -t string -s launcher
        xfconf-query -c xfce4-panel -p "/plugins/plugin-${plugin_id}/items" \
            -n -a -t string -s "$item_name"

        for id in "${new_plugins[@]}"; do
            set_args+=(-t int -s "$id")
        done
        xfconf-query -c xfce4-panel -p "/panels/panel-${panel_id}/plugin-ids" \
            -a "${set_args[@]}"
    fi

    plugin_dir="$HOME/.config/xfce4/panel/launcher-${plugin_id}"
    desktop_file="$plugin_dir/$item_name"
    mkdir -p "$plugin_dir"
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=显示预设
Comment=切换 Termux:X11 分辨率和桌面缩放
Exec=$script_path --gui
Icon=preferences-desktop-display
Terminal=false
StartupNotify=false
Categories=Settings;DesktopSettings;
EOF

    if [ "$created" -eq 1 ]; then
        xfce4-panel -r >/dev/null 2>&1 &
    fi
}

# ---------- 方法 5：精细调整（逐项设置 UI 元素） ----------
apply_fine() {
    local scale=$1
    local dpi=$(python3 -c "print(int(${BASE_DPI} * ${scale}))")

    # 计算各项缩放后的值（沿用原始基准）
    local BASE_FONT_SIZE=10 BASE_PANEL1_SIZE=26 BASE_PANEL1_ICON=16 BASE_PANEL2_SIZE=48
    local BASE_CURSOR_SIZE=16 BASE_DESKTOP_ICON_SIZE=48 BASE_THUNAR_ICON_SIZE=48
    local BASE_THUNAR_COMPACT_ICON=36 BASE_WM_BUTTON_ICON=16
    local BASE_WM_TITLE_FONT="Sans Bold"

    local font_size=$(python3 -c "print(int(${BASE_FONT_SIZE} * ${scale}))")
    local panel1_size=$(python3 -c "print(int(${BASE_PANEL1_SIZE} * ${scale}))")
    local panel1_icon=$(python3 -c "print(int(${BASE_PANEL1_ICON} * ${scale}))")
    local panel2_size=$(python3 -c "print(int(${BASE_PANEL2_SIZE} * ${scale}))")
    local cursor_size=$(python3 -c "print(int(${BASE_CURSOR_SIZE} * ${scale}))")
    local wm_title_size=$(python3 -c "print(int(9 * ${scale}))")
    local desktop_icon_size=$(python3 -c "print(int(${BASE_DESKTOP_ICON_SIZE} * ${scale}))")
    local thunar_icon_size=$(python3 -c "print(int(${BASE_THUNAR_ICON_SIZE} * ${scale}))")
    local thunar_compact_icon=$(python3 -c "print(int(${BASE_THUNAR_COMPACT_ICON} * ${scale}))")
    local wm_button_icon=$(python3 -c "print(int(${BASE_WM_BUTTON_ICON} * ${scale}))")

    font_size=$(python3 -c "print(max(8, ${font_size}))")
    panel1_size=$(python3 -c "print(max(20, ${panel1_size}))")
    panel1_icon=$(python3 -c "print(max(12, ${panel1_icon}))")
    panel2_size=$(python3 -c "print(max(30, ${panel2_size}))")
    cursor_size=$(python3 -c "print(max(12, ${cursor_size}))")
    wm_title_size=$(python3 -c "print(max(8, ${wm_title_size}))")
    desktop_icon_size=$(python3 -c "print(max(24, ${desktop_icon_size}))")
    thunar_icon_size=$(python3 -c "print(max(24, ${thunar_icon_size}))")
    thunar_compact_icon=$(python3 -c "print(max(16, ${thunar_compact_icon}))")
    wm_button_icon=$(python3 -c "print(max(8, ${wm_button_icon}))")

    echo ""
    echo -e "${YELLOW}正在精细应用 (${scale}x)...${NC}"

    xfconf-query -c xsettings -p /Xft/DPI -s "$dpi" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/FontName -s "Sans ${font_size}" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "Monospace ${font_size}" 2>/dev/null || true
    # ToolbarIconSize 是 GTK 枚举而不是像素，不随 scale 写入 24/48；交给 GTK/GDK 缩放。
    xfconf-query -c xsettings -p /Gtk/ToolbarIconSize -r 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s "$cursor_size" 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/size -s "$panel1_size" 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-1/icon-size -s "$panel1_icon" 2>/dev/null || true
    xfconf-query -c xfce4-panel -p /panels/panel-2/size -s "$panel2_size" 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/title_font -s "${BASE_WM_TITLE_FONT} ${wm_title_size}" 2>/dev/null || true
    xfconf-query -c xfwm4 -p /general/button-icon-size -s "$wm_button_icon" --create 2>/dev/null || true
    xfconf-query -c xfdesktop -p /desktop-icons/file-icons/icon-size -s "$desktop_icon_size" --create 2>/dev/null || true
    xfconf-query -c thunar -p /default-view-icon-size -s "$thunar_icon_size" --create 2>/dev/null || true
    xfconf-query -c thunar -p /compact-view-icon-size -s "$thunar_compact_icon" --create 2>/dev/null || true

    local whisker_plugin=$(xfconf-query -c xfce4-panel -p /plugins -lv 2>/dev/null | grep -i whisker | awk '{print $1}' | sed 's/plugins\///')
    if [ -n "$whisker_plugin" ]; then
        xfconf-query -c xfce4-panel -p /plugins/${whisker_plugin}/panel-icon-size -s "$panel1_icon" --create 2>/dev/null || true
        xfconf-query -c xfce4-panel -p /plugins/${whisker_plugin}/menu-icon-size -s "$thunar_icon_size" --create 2>/dev/null || true
    fi

    # Xresources
    cat > ~/.Xresources << EOF
Xft.dpi: ${dpi}
Xft.autohint: 0
Xft.lcdfilter: lcddefault
Xft.hintstyle: hintslight
Xft.hinting: 1
Xft.antialias: 1
Xft.rgba: rgb
EOF
    xrdb -merge ~/.Xresources 2>/dev/null || true

    # 环境变量（修正：不再叠加 GDK_DPI_SCALE，避免双重缩放）
    write_env dpi "$scale"
    update_fcitx5_classicui "$scale"
    update_wechat_desktop "$scale"
    restart_fcitx5_scaled "$scale"

    xfce4-panel -r 2>/dev/null &
    fc-cache -f 2>/dev/null

    echo ""
    echo -e "${GREEN}✓ 精细调整已应用（${scale}x, DPI=${dpi}）${NC}"
}

# ---------- 诊断 ----------
show_diagnose() {
    detect_display
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}          屏幕诊断 / 推荐倍数${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "当前分辨率:   ${GREEN}${CURRENT_RES:-未知}${NC}"
    echo -e "原生分辨率:   ${GREEN}${NATIVE_W}x${NATIVE_H}${NC}"
    echo -e "xrandr 输出:  ${GREEN}${XRANDR_OUTPUT:-无}${NC}"
    echo -e "xrandr 可用:  ${GREEN}$( [ "$XRANDR_OK" -eq 1 ] && echo 是 || echo 否 )${NC}"
    echo -e "当前 Xft DPI: ${GREEN}$(xfconf-query -c xsettings -p /Xft/DPI 2>/dev/null || echo 未知)${NC}"
    echo ""

    if [ -n "$CURRENT_W" ] && [ "$CURRENT_W" -gt 0 ]; then
        echo -e "${YELLOW}各倍数的目标帧缓冲（xrandr 法 / termux 法通用）:${NC}"
        python3 - "$CURRENT_W" "$CURRENT_H" << 'PY'
import sys, math
W, H = int(sys.argv[1]), int(sys.argv[2])
print(f"  {'倍数':>6}  {'目标分辨率':>12}   {'清晰度'}")
for s in [1.0,1.1,1.15,1.2,1.25,1.3,1.333,1.4,1.5,1.6,1.666,1.75,1.8,2.0,2.25,2.5]:
    w = W / s; h = H / s
    crisp = abs(w - round(w)) < 0.5 and abs(h - round(h)) < 0.5
    tag = "清晰(不糊)" if crisp else "略糊"
    print(f"  {s:>6}  {round(w)}x{round(h):<6}   {tag}")
PY
        echo ""
        echo -e "${YELLOW}提示: 标「清晰」的档位缩放后像素点对点，最锐利；其它档会轻微模糊。${NC}"
    fi

    echo ""
    echo -e "  ${YELLOW}n)${NC} 重新探测原生分辨率（若你已换屏/改过）"
    echo -e "  ${YELLOW}q)${NC} 返回"
    echo ""
    read -p "选择: " dchoice
    case $dchoice in
        n|N)
            NATIVE_W=""; NATIVE_H=""
            detect_display
            echo -e "${GREEN}已重新探测：原生=${NATIVE_W}x${NATIVE_H}${NC}"
            sleep 1
            show_diagnose
            ;;
        *)
            return 0
            ;;
    esac
}

# ---------- 查看当前设置 ----------
show_current() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}           当前显示设置${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "  Xft DPI:         ${GREEN}$(xfconf-query -c xsettings -p /Xft/DPI 2>/dev/null || echo 未知)${NC}"
    echo -e "  主字体:          ${GREEN}$(xfconf-query -c xsettings -p /Gtk/FontName 2>/dev/null || echo 未知)${NC}"
    echo -e "  工具栏图标:      ${GREEN}$(xfconf-query -c xsettings -p /Gtk/ToolbarIconSize 2>/dev/null || echo 未设置)px${NC}"
    echo -e "  光标大小:        ${GREEN}$(xfconf-query -c xsettings -p /Gtk/CursorThemeSize 2>/dev/null || echo 未知)px${NC}"
    echo -e "  Panel 1 高度:    ${GREEN}$(xfconf-query -c xfce4-panel -p /panels/panel-1/size 2>/dev/null || echo 未知)px${NC}"
    echo -e "  Panel 1 图标:    ${GREEN}$(xfconf-query -c xfce4-panel -p /panels/panel-1/icon-size 2>/dev/null || echo 未知)px${NC}"
    echo -e "  Xresources DPI:  ${GREEN}$(xrdb -query 2>/dev/null | grep Xft.dpi | awk '{print $2}')${NC}"
    echo -e "  xrandr 当前:     ${GREEN}$(xrandr 2>/dev/null | grep -oP '\d+x\d+(?=\s+\*)|current \K[0-9x]+' | head -1)${NC}"
    echo ""
    echo -e "${YELLOW}.xsessionrc 缩放相关环境变量:${NC}"
    grep -E 'GDK_SCALE|GDK_DPI_SCALE|QT_SCALE_FACTOR|QT_AUTO_SCREEN_SCALE_FACTOR|QT_FONT_DPI|QT_ENABLE_HIGHDPI_SCALING' ~/.xsessionrc 2>/dev/null || echo "  (无)"
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo ""
    read -p "按回车返回菜单..."
}

# ---------- 选择缩放倍数 ----------
pick_scale() {
    SELECTED_SCALE=""
    while true; do
        echo ""
        echo -e "${YELLOW}选择缩放倍数:${NC}"
        echo -e "  ${GREEN}1)${NC} 1.25x   2) 1.5x   3) 1.75x   4) 2.0x"
        echo -e "  ${GREEN}5)${NC} 自定义倍数   ${GREEN}0)${NC} 返回上一级"
        read -p "请输入: " s
        case $s in
            1) SELECTED_SCALE=1.25; return 0 ;;
            2) SELECTED_SCALE=1.5;  return 0 ;;
            3) SELECTED_SCALE=1.75; return 0 ;;
            4) SELECTED_SCALE=2.0;  return 0 ;;
            5) SELECTED_SCALE=$(prompt_scale); return 0 ;;
            0) SELECTED_SCALE=""; return 0 ;;
            *) echo -e "${RED}无效选项！${NC}" ;;
        esac
    done
}

# ---------- 应用某方法 ----------
apply_method() {
    local method=$1
    pick_scale
    if [ -z "$SELECTED_SCALE" ]; then
        return 0
    fi
    case $method in
        xrandr) apply_xrandr_scale "$SELECTED_SCALE" || true ;;
        dpi)    apply_dpi_mode "$SELECTED_SCALE" ;;
        gdk)    apply_gdk_int "$SELECTED_SCALE" ;;
        termux) apply_termux_res "$SELECTED_SCALE" ;;
        fine)   apply_fine "$SELECTED_SCALE" ;;
    esac
    read -p "按回车继续..."
}

# ---------- 命令行入口 / 主循环 ----------
case ${1:-} in
    --gui)
        show_termux_profiles_gui
        exit $?
        ;;
    --profiles)
        show_termux_profiles
        exit 0
        ;;
    --install-panel-launcher)
        ensure_panel_launcher
        exit 0
        ;;
    --install-panel-launcher-wait)
        for _ in {1..60}; do
            if pgrep -x xfce4-panel >/dev/null 2>&1; then
                ensure_panel_launcher
                exit $?
            fi
            sleep 1
        done
        echo "等待 xfce4-panel 启动超时，未安装显示预设按钮。" >&2
        exit 1
        ;;
    --remote-resize)
        [ $# -eq 2 ] || { echo "用法：$0 --remote-resize WIDTHxHEIGHT" >&2; exit 2; }
        apply_remote_resize "$2"
        exit $?
        ;;
    --queue-remote-resize)
        [ $# -eq 2 ] || { echo "用法：$0 --queue-remote-resize WIDTHxHEIGHT" >&2; exit 2; }
        queue_remote_resize "$2"
        exit $?
        ;;
esac

ensure_panel_launcher
while true; do
    show_menu
    read -p "请输入选项: " choice
    case $choice in
        1) apply_method xrandr ;;
        2) apply_method dpi ;;
        3) apply_method gdk ;;
        4) show_termux_profiles ;;
        5) apply_method fine ;;
        d|D) show_diagnose ;;
        v|V) show_current ;;
        0)
            echo -e "${GREEN}再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项！${NC}"
            sleep 1
            ;;
    esac
done
