#!/data/data/com.termux/files/usr/bin/bash

# Termux Chroot 挂载配置管理工具
# 使用方法: bash ~/sh/termux/chroot/mount_config_manager.sh [list|edit|verify|add|remove|help]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOUNT_CONFIG="$SCRIPT_DIR/mount_config.conf"

# 加载cli.sh中的函数
. "$SCRIPT_DIR/cli.sh"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_title() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}Termux Chroot 挂载配置管理工具${NC}

${GREEN}使用方法:${NC}
  $0 [命令] [参数...]

${GREEN}可用命令:${NC}
  ${YELLOW}list${NC}           - 显示当前挂载配置
  ${YELLOW}edit${NC}           - 编辑挂载配置文件
  ${YELLOW}verify${NC}         - 验证配置文件语法
  ${YELLOW}add${NC} <配置行>   - 添加新的挂载配置
  ${YELLOW}remove${NC} <名称>  - 移除指定的挂载配置
  ${YELLOW}enable${NC} <名称>  - 启用指定的挂载配置
  ${YELLOW}disable${NC} <名称> - 禁用指定的挂载配置
  ${YELLOW}status${NC}         - 显示当前挂载状态
  ${YELLOW}help${NC}           - 显示此帮助信息

${GREEN}配置行格式:${NC}
  名称:源路径:目标路径:挂载选项:是否启用
  
${GREEN}示例:${NC}
  $0 add "my_data:/sdcard/MyData:\${CHROOT_DIR}/home/root/MyData:bind:1"
  $0 remove my_data
  $0 enable sdcard
  $0 disable tmp

${GREEN}环境变量:${NC}
  可在配置中使用以下变量:
  \${DEBIAN_DIR}  - Debian安装目录
  \${CHROOT_DIR}  - Chroot挂载目录  
  \${PREFIX}      - Termux前缀目录
EOF
}

# 列出当前配置
list_config() {
    log_title "当前挂载配置"
    
    if [ ! -f "$MOUNT_CONFIG" ]; then
        log_error "配置文件不存在: $MOUNT_CONFIG"
        return 1
    fi
    
    # 导出变量
    export DEBIAN_DIR CHROOT_DIR PREFIX
    
    printf "%-15s %-8s %-35s %-35s %s\n" "名称" "状态" "源路径" "目标路径" "选项"
    echo "$(printf '%*s' 120 '' | tr ' ' '-')"
    
    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        
        # 跳过注释和空行
        case "$line" in
            \#*|'') continue ;;
        esac
        
        # 解析配置行
        local parsed
        if parsed=$(parse_mount_config_line "$line" 2>/dev/null); then
            read -r name source target options enabled <<< "$parsed"
            local status="${GREEN}启用${NC}"
            [ "$enabled" != "1" ] && status="${RED}禁用${NC}"
            
            printf "%-15s %-8s %-35s %-35s %s\n" \
                "$name" \
                "$(echo -e "$status")" \
                "$source" \
                "$target" \
                "$options"
        else
            log_warn "第 $line_num 行格式错误: $line"
        fi
    done < "$MOUNT_CONFIG"
}

# 验证配置文件
verify_config() {
    log_title "验证挂载配置"
    
    if [ ! -f "$MOUNT_CONFIG" ]; then
        log_error "配置文件不存在: $MOUNT_CONFIG"
        return 1
    fi
    
    # 导出变量
    export DEBIAN_DIR CHROOT_DIR PREFIX
    
    local errors=0
    local warnings=0
    local line_num=0
    
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        
        # 跳过注释和空行
        case "$line" in
            \#*|'') continue ;;
        esac
        
        # 验证配置行
        local parsed
        if parsed=$(parse_mount_config_line "$line" 2>/dev/null); then
            read -r name source target options enabled <<< "$parsed"
            
            # 检查源路径
            if [ ! -e "$source" ] && [[ "$options" != *tmpfs* ]] && [[ "$options" != *proc* ]] && [[ "$options" != *sysfs* ]]; then
                log_warn "第 $line_num 行: 源路径不存在: $source"
                warnings=$((warnings + 1))
            fi
            
            # 检查启用标志
            if [ "$enabled" != "0" ] && [ "$enabled" != "1" ]; then
                log_error "第 $line_num 行: 启用标志必须是0或1: $enabled"
                errors=$((errors + 1))
            fi
            
        else
            log_error "第 $line_num 行: 格式错误: $line"
            errors=$((errors + 1))
        fi
    done < "$MOUNT_CONFIG"
    
    if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
        log_info "配置文件验证通过"
    else
        log_info "验证完成: $errors 个错误, $warnings 个警告"
    fi
    
    return $errors
}

# 编辑配置文件
edit_config() {
    log_info "编辑挂载配置文件: $MOUNT_CONFIG"
    
    # 选择编辑器
    local editor="nano"
    if command -v vim >/dev/null 2>&1; then
        editor="vim"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    fi
    
    # 备份原文件
    if [ -f "$MOUNT_CONFIG" ]; then
        cp "$MOUNT_CONFIG" "$MOUNT_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "已创建备份文件"
    fi
    
    $editor "$MOUNT_CONFIG"
    
    # 验证编辑后的文件
    if verify_config; then
        log_info "配置文件已保存并验证通过"
    else
        log_warn "配置文件可能有问题，请检查"
    fi
}

# 添加挂载配置
add_config() {
    local config_line="$1"
    
    if [ -z "$config_line" ]; then
        log_error "请提供配置行"
        echo "格式: 名称:源路径:目标路径:挂载选项:是否启用"
        return 1
    fi
    
    # 验证配置行格式
    export DEBIAN_DIR CHROOT_DIR PREFIX
    if ! parse_mount_config_line "$config_line" >/dev/null 2>&1; then
        log_error "配置行格式错误: $config_line"
        return 1
    fi
    
    # 添加到配置文件
    echo "" >> "$MOUNT_CONFIG"
    echo "# 用户添加 $(date)" >> "$MOUNT_CONFIG"
    echo "$config_line" >> "$MOUNT_CONFIG"
    
    log_info "已添加挂载配置: $config_line"
}

# 移除挂载配置
remove_config() {
    local mount_name="$1"
    
    if [ -z "$mount_name" ]; then
        log_error "请提供要移除的挂载名称"
        return 1
    fi
    
    if [ ! -f "$MOUNT_CONFIG" ]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    # 创建备份
    cp "$MOUNT_CONFIG" "$MOUNT_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 移除配置行
    if sed -i "/^${mount_name}:/d" "$MOUNT_CONFIG" 2>/dev/null; then
        log_info "已移除挂载配置: $mount_name"
    else
        log_error "未找到挂载配置: $mount_name"
        return 1
    fi
}

# 启用/禁用挂载配置
toggle_config() {
    local mount_name="$1"
    local action="$2"  # enable 或 disable
    
    if [ -z "$mount_name" ]; then
        log_error "请提供挂载名称"
        return 1
    fi
    
    if [ ! -f "$MOUNT_CONFIG" ]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    local new_value
    case "$action" in
        enable) new_value="1" ;;
        disable) new_value="0" ;;
        *) log_error "无效的操作: $action"; return 1 ;;
    esac
    
    # 创建备份
    cp "$MOUNT_CONFIG" "$MOUNT_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 修改配置
    if sed -i "s/^${mount_name}:\(.*:\).$/${mount_name}:\1${new_value}/" "$MOUNT_CONFIG" 2>/dev/null; then
        log_info "已${action}挂载配置: $mount_name"
    else
        log_error "未找到挂载配置: $mount_name"
        return 1
    fi
}

# 显示当前挂载状态
show_status() {
    log_title "当前挂载状态"
    
    if container_mounted; then
        log_info "Chroot容器: 已挂载"
        echo ""
        echo "挂载点信息:"
        mount | grep "$CHROOT_DIR" | while read -r line; do
            echo "  $line"
        done
    else
        log_warn "Chroot容器: 未挂载"
    fi
}

# 主函数
main() {
    case "${1:-help}" in
        list|ls)
            list_config
            ;;
        edit|e)
            edit_config
            ;;
        verify|check)
            verify_config
            ;;
        add)
            add_config "$2"
            ;;
        remove|rm)
            remove_config "$2"
            ;;
        enable)
            toggle_config "$2" "enable"
            ;;
        disable)
            toggle_config "$2" "disable"
            ;;
        status)
            show_status
            ;;
        help|h|*)
            show_help
            ;;
    esac
}

# 运行主函数
main "$@" 