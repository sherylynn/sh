#!/data/data/com.termux/files/usr/bin/bash

# Chroot Linux 管理脚本
# 模拟 Linux Deploy 的启动和停止功能
# 使用方法: bash ~/sh/termux/chroot_manager.sh [start|stop|restart|status|shell]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 加载必要的函数
. "$PROJECT_ROOT/win-git/toolsinit.sh"
. "$SCRIPT_DIR/chroot/cli.sh"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 检查chroot环境是否已安装
check_chroot_installed() {
    if [ ! -d "$DEBIAN_DIR" ] || [ ! -e "$DEBIAN_DIR/bin/dpkg" ]; then
        log_error "Chroot Debian环境未安装"
        log_info "请先运行: bash ~/sh/termux/chroot/installer_ruri.sh"
        return 1
    fi
    return 0
}

# 启动chroot环境 - 模拟Linux Deploy的start功能
start_chroot_container() {
    log_info "启动chroot Linux容器..."
    
    # 检查是否已经挂载
    if container_mounted; then
        log_warn "容器已经在运行中"
        return 0
    fi
    
    # 检查环境
    check_chroot_installed || return 1
    
    log_debug "开始挂载文件系统..."
    
    # 修复setuid问题
    sudo $busybox mount -o remount,dev,suid /data
    
    # 挂载根文件系统
    log_debug "挂载根文件系统: $DEBIAN_DIR -> $CHROOT_DIR"
    if ! is_mounted "${CHROOT_DIR}"; then
        [ -d "${CHROOT_DIR}" ] || sudo mkdir -p "${CHROOT_DIR}"
        sudo $busybox mount -o bind "${DEBIAN_DIR}" "${CHROOT_DIR}"
        sudo $busybox mount -o remount,exec,suid,dev "${CHROOT_DIR}"
    fi
    
    # 挂载必要的系统目录
    local mount_points=(
        "/dev:$CHROOT_DIR/dev:bind"
        "/sys:$CHROOT_DIR/sys:sysfs"
        "/proc:$CHROOT_DIR/proc:proc"
        "/dev/pts:$CHROOT_DIR/dev/pts:bind"
        "/dev/shm:$CHROOT_DIR/dev/shm:bind"
        "/sdcard:$CHROOT_DIR/sdcard:bind"
        "$PREFIX/tmp:$CHROOT_DIR/tmp:bind"
    )
    
    for mount_info in "${mount_points[@]}"; do
        IFS=':' read -r source target type <<< "$mount_info"
        
        if ! is_mounted "$target"; then
            [ -d "$target" ] || sudo mkdir -p "$target"
            
            case "$type" in
                "bind")
                    [ -d "$source" ] || sudo mkdir -p "$source"
                    sudo $busybox mount --bind "$source" "$target"
                    ;;
                "sysfs")
                    sudo $busybox mount -t sysfs sys "$target"
                    ;;
                "proc")
                    sudo $busybox mount -t proc proc "$target"
                    ;;
            esac
            
            if [ $? -eq 0 ]; then
                log_debug "挂载成功: $target"
            else
                log_error "挂载失败: $target"
                return 1
            fi
        else
            log_debug "已挂载: $target"
        fi
    done
    
    # 特殊处理/dev/pts
    if ! is_mounted "/dev/pts"; then
        [ -d "/dev/pts" ] || sudo mkdir -p /dev/pts
        sudo $busybox mount -o rw,nosuid,noexec,gid=5,mode=620,ptmxmode=000 -t devpts devpts /dev/pts
    fi
    
    # 特殊处理/dev/shm
    if ! is_mounted "/dev/shm"; then
        [ -d "/dev/shm" ] || sudo mkdir -p /dev/shm
        sudo $busybox mount -o rw,nosuid,nodev,mode=1777 -t tmpfs tmpfs /dev/shm
    fi
    
    # 配置网络
    log_debug "配置网络..."
    chroot_exec -u root bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'
    chroot_exec -u root bash -c 'echo "127.0.0.1 localhost" > /etc/hosts'
    
    # 启动dbus服务
    log_debug "启动D-Bus服务..."
    config_dbus
    start_dbus
    
    # 设置环境变量
    export DISPLAY=:1
    export PULSE_RUNTIME_PATH=/run/user/$(id -u)/pulse
    
    log_info "Chroot Linux容器启动完成！"
    return 0
}

# 停止chroot环境 - 模拟Linux Deploy的stop功能
stop_chroot_container() {
    log_info "停止chroot Linux容器..."
    
    if ! container_mounted; then
        log_warn "容器未运行"
        return 0
    fi
    
    # 停止服务
    log_debug "停止D-Bus服务..."
    stop_dbus 2>/dev/null || true
    
    log_debug "停止VNC服务..."
    stop_vnc 2>/dev/null || true
    
    # 终止使用chroot的进程
    log_debug "释放chroot资源..."
    local lsof_full=$(sudo $busybox lsof 2>/dev/null | awk '{print $1}' | grep -c '^lsof' || echo "0")
    if [ "${lsof_full}" -eq 0 ]; then
        local pids=$(sudo $busybox lsof 2>/dev/null | grep "${CHROOT_DIR%/}" | awk '{print $1}' | uniq || true)
    else
        local pids=$(sudo $busybox lsof 2>/dev/null | grep "${CHROOT_DIR%/}" | awk '{print $2}' | uniq || true)
    fi
    
    if [ -n "$pids" ]; then
        log_debug "终止进程: $pids"
        sudo kill -TERM $pids 2>/dev/null || true
        sleep 2
        sudo kill -KILL $pids 2>/dev/null || true
    fi
    
    # 卸载文件系统
    log_debug "卸载文件系统..."
    
    # 获取所有挂载点并反向排序
    local mount_points=$(sudo cat /proc/mounts 2>/dev/null | awk '{print $2}' | grep "^${CHROOT_DIR%/}/" | sort -r || true)
    
    for mount_point in $mount_points; do
        local mount_name=$(echo $mount_point | sed "s|^${CHROOT_DIR%/}/*|/|g")
        log_debug "卸载: $mount_name"
        
        for i in 1 2 3; do
            if sudo $busybox umount "$mount_point" 2>/dev/null; then
                break
            fi
            sleep 1
        done
    done
    
    # 卸载根文件系统
    if is_mounted "${CHROOT_DIR}"; then
        log_debug "卸载根文件系统..."
        for i in 1 2 3; do
            if sudo $busybox umount "${CHROOT_DIR}" 2>/dev/null; then
                break
            fi
            sleep 1
        done
    fi
    
    # 清理临时文件
    clean_tmp
    
    log_info "Chroot Linux容器已停止"
    return 0
}

# 检查状态
check_chroot_status() {
    echo -e "${BLUE}=== Chroot Linux 容器状态 ===${NC}"
    
    echo -n "容器状态: "
    if container_mounted; then
        echo -e "${GREEN}运行中${NC}"
    else
        echo -e "${RED}已停止${NC}"
    fi
    
    echo -n "Debian环境: "
    if check_chroot_installed 2>/dev/null; then
        echo -e "${GREEN}已安装${NC} ($(ls -la "$DEBIAN_DIR/bin/dpkg" 2>/dev/null | awk '{print $6" "$7" "$8}' || echo '未知'))"
    else
        echo -e "${RED}未安装${NC}"
    fi
    
    echo -n "D-Bus服务: "
    if is_started /run/dbus/pid /run/dbus/messagebus.pid /run/messagebus.pid /var/run/dbus/pid /var/run/dbus/messagebus.pid /var/run/messagebus.pid >/dev/null 2>&1; then
        echo -e "${GREEN}运行中${NC}"
    else
        echo -e "${RED}已停止${NC}"
    fi
    
    if container_mounted; then
        echo
        echo -e "${BLUE}=== 挂载点信息 ===${NC}"
        mount | grep "$CHROOT_DIR" | while read line; do
            echo "  $line"
        done
        
        echo
        echo -e "${BLUE}=== 系统信息 ===${NC}"
        chroot_exec -u root cat /etc/os-release 2>/dev/null | grep "^PRETTY_NAME" | cut -d'=' -f2 | tr -d '"' | sed 's/^/  系统: /' || echo "  系统: 未知"
        chroot_exec -u root uptime 2>/dev/null | sed 's/^/  运行时间: /' || true
        chroot_exec -u root df -h / 2>/dev/null | tail -n1 | awk '{print "  磁盘使用: "$3"/"$2" ("$5")"}' || true
    fi
}

# 进入chroot shell
enter_chroot_shell() {
    if ! container_mounted; then
        log_error "容器未运行，请先启动: $0 start"
        return 1
    fi
    
    log_info "进入Chroot Linux环境..."
    log_info "提示: 输入 'exit' 退出chroot环境"
    
    # 设置环境变量
    export DISPLAY=:1
    export PULSE_RUNTIME_PATH=/run/user/$(id -u)/pulse
    
    # 进入chroot
    chroot_exec -u root
}

# 在chroot中执行单个命令
exec_chroot_command() {
    if ! container_mounted; then
        log_error "容器未运行，请先启动: $0 start"
        return 1
    fi
    
    if [ $# -eq 0 ]; then
        log_error "请提供要执行的命令"
        return 1
    fi
    
    log_debug "在chroot中执行: $*"
    
    # 设置环境变量
    export DISPLAY=:1
    export PULSE_RUNTIME_PATH=/run/user/$(id -u)/pulse
    
    # 执行命令
    chroot_exec -u root "$@"
}

# 显示使用帮助
show_help() {
    cat << EOF
${BLUE}Chroot Linux 管理脚本${NC}

${GREEN}使用方法:${NC}
  $0 [命令] [参数...]

${GREEN}可用命令:${NC}
  ${YELLOW}start${NC}         启动chroot Linux容器
  ${YELLOW}stop${NC}          停止chroot Linux容器  
  ${YELLOW}restart${NC}       重启chroot Linux容器
  ${YELLOW}status${NC}        查看容器状态
  ${YELLOW}shell${NC}         进入chroot Linux shell
  ${YELLOW}exec${NC} <命令>   在chroot中执行命令
  ${YELLOW}install${NC}       安装Debian环境
  
${GREEN}示例:${NC}
  $0 start                    # 启动容器
  $0 shell                    # 进入Linux shell
  $0 exec ls -la /root        # 执行命令
  $0 exec "apt update && apt upgrade -y"  # 更新系统

${GREEN}快捷别名建议:${NC}
  echo 'alias cstart="bash ~/sh/termux/chroot_manager.sh start"' >> ~/.zshrc
  echo 'alias cstop="bash ~/sh/termux/chroot_manager.sh stop"' >> ~/.zshrc  
  echo 'alias cshell="bash ~/sh/termux/chroot_manager.sh shell"' >> ~/.zshrc
  echo 'alias cstatus="bash ~/sh/termux/chroot_manager.sh status"' >> ~/.zshrc
EOF
}

# 安装Debian环境
install_debian_env() {
    if check_chroot_installed 2>/dev/null; then
        log_info "Debian环境已安装"
        return 0
    fi
    
    log_info "开始安装Debian环境..."
    bash "$SCRIPT_DIR/chroot/installer_ruri.sh"
    
    if check_chroot_installed 2>/dev/null; then
        log_info "Debian环境安装完成！"
    else
        log_error "Debian环境安装失败"
        return 1
    fi
}

# 主函数
main() {
    local command="${1:-help}"
    
    case "$command" in
        "start")
            start_chroot_container
            ;;
        "stop")
            stop_chroot_container
            ;;
        "restart")
            stop_chroot_container
            sleep 2
            start_chroot_container
            ;;
        "status")
            check_chroot_status
            ;;
        "shell")
            enter_chroot_shell
            ;;
        "exec")
            shift
            exec_chroot_command "$@"
            ;;
        "install")
            install_debian_env
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            echo
            show_help
            exit 1
            ;;
    esac
}

# 设置权限和执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 确保脚本有执行权限
    chmod +x "$0" 2>/dev/null || true
    
    # 执行主函数
    main "$@"
fi 