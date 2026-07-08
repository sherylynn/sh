#!/bin/bash
# XFCE4 高分屏缩放 / DPI 设置脚本（多屏 / 多方法版）
# 适用于 Termux chroot + termux-x11（真实 X 后端）+ VNC 监控 + 骁龙 GPU 驱动
#
# 设计目标：
#   - 提供多种「缩放实现（方法）」，哪个在你的环境能用，你自己挑。
#   - xrandr 整体缩放：让 xrandr 接管整屏（统一、GPU 加速、VNC 同步可见）。
#   - DPI + 环境变量：不依赖 xrandr，纯文本/工具包缩放（到处能用）。
#   - XFCE 全局整数缩放(Gdk/WindowScalingFactor)：屏幕分辨率保持原生(1:1)，UI 按整数倍绘制，真·视网膜最清晰，推荐。
#   - termux-x11 原生分辨率：直接改 X 服务器分辨率（最稳，但需重启 X 会话）。
#   - 精细调整：逐项设字体/面板/图标/光标（老方法保留）。
#   - 切换方法时会先「复位」其它机制，避免叠加导致双重缩放。

set -e

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
# 注意：不会改动 termux-x11 的原生分辨率（那是持久且需重启会话的），
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
            # Xft.dpi 已单独放大；GTK 不再叠加 GDK_DPI_SCALE，Qt 用 QT_SCALE_FACTOR
            # 并设 QT_FONT_DPI=96 抵消 Xft.dpi 对 Qt 文字的二次放大
            cat >> ~/.xsessionrc << EOF
# Display scaling (dpi) ${scale}x
export GDK_SCALE=1
export GDK_DPI_SCALE=1
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
    echo -e "  ${GREEN}4)${NC} termux-x11 降低分辨率 ${BLUE}(改小帧缓冲→UI变大但上采样变糊，非视网膜)${NC}"
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

# ---------- 方法 2：DPI + 环境变量 ----------
apply_dpi_mode() {
    local scale=$1
    reset_scaling
    local dpi=$(python3 -c "print(int(${BASE_DPI} * ${scale}))")
    xfconf-query -c xsettings -p /Xft/DPI -s "$dpi" 2>/dev/null || true
    write_env dpi "$scale"
    echo ""
    echo -e "${GREEN}✓ DPI 缩放 ${scale}x 已应用（Xft.dpi=${dpi}）${NC}"
    echo -e "${YELLOW}注意: GTK3 不支持分数 GDK_SCALE，UI 控件仍为 1x（文字大、控件略紧）；${NC}"
    echo -e "${YELLOW}      Qt 程序按 ${scale}x 缩放。若某些程序偏小，可试方法 1/3/4。${NC}"
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
    # Qt 程序：用环境变量（仅影响之后启动的 Qt 程序）；GTK 已由 WindowScalingFactor 处理，故不设 GDK_SCALE
    write_env qt_only "$gdk"
    # 让面板立即套用
    xfce4-panel -r 2>/dev/null &
    echo ""
    echo -e "${GREEN}✓ XFCE 全局整数缩放 ${gdk}x 已应用${NC}"
    echo -e "${YELLOW}  - Gdk/WindowScalingFactor=${gdk}（GTK3 全局，已运行程序经 xfsettingsd 广播生效）${NC}"
    echo -e "${YELLOW}  - 逻辑桌面缩小为 ${gdk}x，每个逻辑像素由 ${gdk}x${gdk}=$((gdk*gdk)) 个物理像素绘制 → 清晰${NC}"
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
    echo ""
    echo -e "${YELLOW}此操作会把 termux-x11 分辨率改为 ${tw}x${th}（≈${scale}x 放大）。${NC}"
    echo -e "${RED}注意: 这把帧缓冲改小、由手机上采样放大 → 与「视网膜清晰」相反，会糊。视网膜请改用方法 3。${NC}"
    echo -e "${RED}警告: 修改后通常需要重启 termux-x11 的 X 会话才能生效，当前桌面会结束。${NC}"
    read -p "确认继续? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo -e "${YELLOW}已取消。${NC}"
        return 0
    fi
    reset_scaling
    if command -v termux-x11-preference >/dev/null 2>&1; then
        termux-x11-preference "resolution:${tw}x${th}" 2>/dev/null || true
        echo -e "${GREEN}✓ 已设置 termux-x11 分辨率偏好为 ${tw}x${th}${NC}"
    else
        echo -e "${RED}未找到 termux-x11-preference，请手动在 termux-x11 App 设置里改分辨率。${NC}"
    fi
    echo -e "${YELLOW}请重启 termux-x11 App 使分辨率生效（VNC 也会同步）。${NC}"
    # 注意：此处不自动 am start 重启，避免误杀当前会话
}

# ---------- 方法 5：精细调整（逐项设置 UI 元素） ----------
apply_fine() {
    local scale=$1
    local dpi=$(python3 -c "print(int(${BASE_DPI} * ${scale}))")

    # 计算各项缩放后的值（沿用原始基准）
    local BASE_FONT_SIZE=10 BASE_PANEL1_SIZE=26 BASE_PANEL1_ICON=16 BASE_PANEL2_SIZE=48
    local BASE_CURSOR_SIZE=16 BASE_DESKTOP_ICON_SIZE=48 BASE_THUNAR_ICON_SIZE=48
    local BASE_THUNAR_COMPACT_ICON=36 BASE_WM_BUTTON_ICON=16 BASE_TOOLBAR_ICON_SIZE=24
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
    local toolbar_icon_size=$(python3 -c "print(int(${BASE_TOOLBAR_ICON_SIZE} * ${scale}))")

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
    toolbar_icon_size=$(python3 -c "print(max(16, ${toolbar_icon_size}))")

    echo ""
    echo -e "${YELLOW}正在精细应用 (${scale}x)...${NC}"

    xfconf-query -c xsettings -p /Xft/DPI -s "$dpi" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/FontName -s "Sans ${font_size}" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "Monospace ${font_size}" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/ToolbarIconSize -s "$toolbar_icon_size" --create 2>/dev/null || true
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

# ---------- 主循环 ----------
while true; do
    show_menu
    read -p "请输入选项: " choice
    case $choice in
        1) apply_method xrandr ;;
        2) apply_method dpi ;;
        3) apply_method gdk ;;
        4) apply_method termux ;;
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
