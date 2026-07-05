#!/bin/bash
# XFCE4 显示缩放/DPI 设置脚本
# 适用于 Termux chroot xfce4 环境，分辨率 2560x1080

set -e

# 默认基准值（当前系统的原始值）
BASE_DPI=100
BASE_FONT_SIZE=10
BASE_MONO_FONT="Monospace"
BASE_PANEL1_SIZE=26
BASE_PANEL1_ICON=16
BASE_PANEL2_SIZE=48
BASE_WM_TITLE_FONT="Sans Bold"
BASE_CURSOR_SIZE=16

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 显示菜单
show_menu() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}     XFCE4 显示缩放/DPI 设置工具${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "当前分辨率: ${GREEN}2560x1080${NC}"
    echo -e "基准 DPI:   ${GREEN}${BASE_DPI}${NC}"
    echo ""
    echo -e "${YELLOW}请选择缩放模式:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} 1.25倍缩放 (DPI: 125)"
    echo -e "  ${GREEN}2)${NC} 1.5倍缩放 (DPI: 150)"
    echo -e "  ${GREEN}3)${NC} 1.75倍缩放 (DPI: 175)"
    echo -e "  ${GREEN}4)${NC} 2倍缩放   (DPI: 200)"
    echo -e "  ${GREEN}5)${NC} 自定义倍数"
    echo -e "  ${GREEN}6)${NC} 直接设置 DPI 值"
    echo -e "  ${GREEN}7)${NC} 恢复默认 (DPI: 100)"
    echo -e "  ${GREEN}8)${NC} 查看当前设置"
    echo -e "  ${GREEN}0)${NC} 退出"
    echo ""
    echo -e "${CYAN}========================================${NC}"
}

# 应用缩放设置
apply_scale() {
    local scale=$1
    local dpi=$(python3 -c "print(int(${BASE_DPI} * ${scale}))")
    apply_dpi "$dpi"
}

# 直接设置 DPI
apply_dpi() {
    local dpi=$1
    local scale=$(python3 -c "print(${dpi} / ${BASE_DPI})")
    
    # 计算各项缩放后的值
    local font_size=$(python3 -c "print(int(${BASE_FONT_SIZE} * ${scale}))")
    local panel1_size=$(python3 -c "print(int(${BASE_PANEL1_SIZE} * ${scale}))")
    local panel1_icon=$(python3 -c "print(int(${BASE_PANEL1_ICON} * ${scale}))")
    local panel2_size=$(python3 -c "print(int(${BASE_PANEL2_SIZE} * ${scale}))")
    local cursor_size=$(python3 -c "print(int(${BASE_CURSOR_SIZE} * ${scale}))")
    local wm_title_size=$(python3 -c "print(int(9 * ${scale}))")
    
    # 确保值不小于1
    font_size=$(python3 -c "print(max(8, ${font_size}))")
    panel1_size=$(python3 -c "print(max(20, ${panel1_size}))")
    panel1_icon=$(python3 -c "print(max(12, ${panel1_icon}))")
    panel2_size=$(python3 -c "print(max(30, ${panel2_size}))")
    cursor_size=$(python3 -c "print(max(12, ${cursor_size}))")
    wm_title_size=$(python3 -c "print(max(8, ${wm_title_size}))")
    
    echo ""
    echo -e "${YELLOW}正在应用设置...${NC}"
    echo -e "  DPI:          ${GREEN}${dpi}${NC} (${scale}x)"
    echo -e "  字体大小:     ${GREEN}${font_size}${NC}"
    echo -e "  面板高度:     ${GREEN}${panel1_size}${NC}px"
    echo -e "  面板图标:     ${GREEN}${panel1_icon}${NC}px"
    echo -e "  光标大小:     ${GREEN}${cursor_size}${NC}px"
    echo -e "  WM标题字体:   ${GREEN}${BASE_WM_TITLE_FONT} ${wm_title_size}${NC}"
    echo ""
    
    # 1. 设置 Xft DPI (xfconf)
    xfconf-query -c xsettings -p /Xft/DPI -s "$dpi"
    
    # 2. 设置字体
    xfconf-query -c xsettings -p /Gtk/FontName -s "Sans ${font_size}"
    xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "Monospace ${font_size}"
    
    # 3. 设置光标
    xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s "$cursor_size"
    
    # 4. 设置面板
    xfconf-query -c xfce4-panel -p /panels/panel-1/size -s "$panel1_size"
    xfconf-query -c xfce4-panel -p /panels/panel-1/icon-size -s "$panel1_icon"
    xfconf-query -c xfce4-panel -p /panels/panel-2/size -s "$panel2_size"
    
    # 5. 设置窗口管理器标题字体
    xfconf-query -c xfwm4 -p /general/title_font -s "${BASE_WM_TITLE_FONT} ${wm_title_size}"
    
    # 6. 更新 Xresources
    cat > ~/.Xresources << EOF
Xft.dpi: ${dpi}
Xft.autohint: 0
Xft.lcdfilter: lcddefault
Xft.hintstyle: hintslight
Xft.hinting: 1
Xft.antialias: 1
Xft.rgba: rgb
EOF
    xrdb -merge ~/.Xresources
    
    # 7. 设置环境变量（写入 .xsessionrc）
    if [ -f ~/.xsessionrc ]; then
        # 移除旧的缩放设置
        sed -i '/# Display scaling/d; /GDK_SCALE/d; /GDK_DPI_SCALE/d; /QT_SCALE_FACTOR/d; /QT_AUTO_SCREEN_SCALE_FACTOR/d' ~/.xsessionrc
    fi
    
    cat >> ~/.xsessionrc << EOF
# Display scaling ${scale}x
export GDK_SCALE=1
export GDK_DPI_SCALE=${scale}
export QT_SCALE_FACTOR=${scale}
export QT_AUTO_SCREEN_SCALE_FACTOR=0
EOF
    
    # 8. 刷新面板
    xfce4-panel -r 2>/dev/null &
    
    # 9. 刷新字体缓存
    fc-cache -f 2>/dev/null
    
    echo ""
    echo -e "${GREEN}✓ 设置已应用！${NC}"
    echo ""
    echo -e "${YELLOW}提示:${NC}"
    echo -e "  - 大部分设置已立即生效"
    echo -e "  - 环境变量需要重新登录后完全生效"
    echo -e "  - 如需完全生效，建议注销后重新登录"
    echo ""
}

# 查看当前设置
show_current() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}           当前显示设置${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "  Xft DPI:         ${GREEN}$(xfconf-query -c xsettings -p /Xft/DPI)${NC}"
    echo -e "  主字体:          ${GREEN}$(xfconf-query -c xsettings -p /Gtk/FontName)${NC}"
    echo -e "  等宽字体:        ${GREEN}$(xfconf-query -c xsettings -p /Gtk/MonospaceFontName)${NC}"
    echo -e "  光标大小:        ${GREEN}$(xfconf-query -c xsettings -p /Gtk/CursorThemeSize)px${NC}"
    echo -e "  Panel 1 高度:    ${GREEN}$(xfconf-query -c xfce4-panel -p /panels/panel-1/size)px${NC}"
    echo -e "  Panel 1 图标:    ${GREEN}$(xfconf-query -c xfce4-panel -p /panels/panel-1/icon-size)px${NC}"
    echo -e "  Panel 2 高度:    ${GREEN}$(xfconf-query -c xfce4-panel -p /panels/panel-2/size)px${NC}"
    echo -e "  WM标题字体:      ${GREEN}$(xfconf-query -c xfwm4 -p /general/title_font)${NC}"
    echo ""
    echo -e "  Xresources DPI:  ${GREEN}$(xrdb -query | grep Xft.dpi | awk '{print $2}')${NC}"
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo ""
    read -p "按回车返回菜单..."
}

# 主循环
while true; do
    show_menu
    read -p "请输入选项 [0-8]: " choice
    
    case $choice in
        1)
            apply_scale 1.25
            read -p "按回车继续..."
            ;;
        2)
            apply_scale 1.5
            read -p "按回车继续..."
            ;;
        3)
            apply_scale 1.75
            read -p "按回车继续..."
            ;;
        4)
            apply_scale 2.0
            read -p "按回车继续..."
            ;;
        5)
            echo ""
            read -p "请输入缩放倍数 (如 1.35): " custom_scale
            if [[ "$custom_scale" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                apply_scale "$custom_scale"
            else
                echo -e "${RED}无效的倍数！${NC}"
            fi
            read -p "按回车继续..."
            ;;
        6)
            echo ""
            read -p "请输入 DPI 值 (如 144): " custom_dpi
            if [[ "$custom_dpi" =~ ^[0-9]+$ ]]; then
                apply_dpi "$custom_dpi"
            else
                echo -e "${RED}无效的 DPI 值！${NC}"
            fi
            read -p "按回车继续..."
            ;;
        7)
            apply_scale 1.0
            read -p "按回车继续..."
            ;;
        8)
            show_current
            ;;
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
