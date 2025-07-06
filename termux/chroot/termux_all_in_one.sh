#!/data/data/com.termux/files/usr/bin/bash

# Termux 一键启动脚本 - 整合所有功能
# 使用方法: bash ~/sh/termux/chroot/termux_all_in_one.sh [start|stop|restart|status]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 加载工具函数
. "$PROJECT_ROOT/win-git/toolsinit.sh"
. "$SCRIPT_DIR/cli.sh"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    log "ERROR: $1" >&2
    exit 1
}

# 检查必要的权限和环境
check_requirements() {
    log "检查运行环境..."
    
    # 检查root权限
    if ! sudo true 2>/dev/null; then
        error "需要root权限，请确保已获取root权限"
    fi
    
    # 检查必要的包
    local required_packages=("termux-x11-nightly" "tsu" "pulseaudio" "virglrenderer-android")
    for pkg in "${required_packages[@]}"; do
        if ! pkg list-installed 2>/dev/null | grep -q "^$pkg/"; then
            log "安装必要的包: $pkg"
            pkg install "$pkg" -y || error "无法安装 $pkg"
        fi
    done
    
    log "环境检查完成"
}

# 启动基础服务
start_base_services() {
    log "启动基础服务..."
    
    # 启动必要的sv服务
    local services=("virgl" "pulseaudio" "x11")
    for service in "${services[@]}"; do
        if [ -d "$PREFIX/var/service/$service" ]; then
            log "启动服务: $service"
            sv up "$service" 2>/dev/null || true
        fi
    done
}

# 启动X11服务
start_x11() {
    log "启动X11服务..."
    
    # 清理旧的进程
    sudo killall -9 termux-x11 Xwayland termux-wake-lock 2>/dev/null || true
    sudo pkill -f com.termux.x11 2>/dev/null || true
    am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 2>/dev/null || true
    
    # 清理临时文件
    clean_tmp
    
    # 启动X11应用
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity 2>/dev/null || true
    
    # 启动X11服务器
    export XDG_RUNTIME_DIR="${TMPDIR}"
    termux-x11 :1 -ac +extension DPMS &
    
    sleep 2
    log "X11服务启动完成"
}

# 启动chroot linux (调用cli.sh中的函数)
start_chroot() {
    log "启动chroot Linux环境..."
    
    # 直接调用cli.sh中的完整实现
    if ! start_chroot_container; then
        error "无法启动chroot环境"
    fi
    
    log "Chroot Linux环境启动完成 (包括初始化系统服务)"
    log "可以使用以下命令进入Linux环境:"
    log "  tenter 或 cshell"
}

# 停止所有服务
stop_all() {
    log "停止所有服务..."
    
    # 停止chroot容器 (调用cli.sh中的完整实现)
    stop_chroot_container 2>/dev/null || true
    
    # 停止X11
    sudo killall -9 termux-x11 Xwayland termux-wake-lock 2>/dev/null || true
    sudo pkill -f com.termux.x11 2>/dev/null || true
    am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 2>/dev/null || true
    
    # 停止sv服务
    local services=("virgl" "pulseaudio" "x11")
    for service in "${services[@]}"; do
        if [ -d "$PREFIX/var/service/$service" ]; then
            sv down "$service" 2>/dev/null || true
        fi
    done
    
    # 清理进程
    kill_need 2>/dev/null || true
    clean_tmp
    
    log "所有服务已停止"
}

# 检查状态 (整合X11和chroot状态)
check_status() {
    echo "=== Termux 整体环境状态 ==="
    
    echo -n "X11服务: "
    if pgrep -f "termux-x11" >/dev/null; then
        echo "运行中"
    else
        echo "已停止"
    fi
    
    # 调用cli.sh中的详细chroot状态检查
    check_chroot_status
    
    echo
    echo "=== X11 进程信息 ==="
    echo "X11进程:"
    pgrep -f "termux-x11" | head -5 || echo "  无"
}

# 进入chroot环境 (调用cli.sh中的函数)
enter_chroot() {
    log "进入chroot Linux环境..."
    enter_chroot_shell
}

# 在chroot中执行命令 (调用cli.sh中的函数)
exec_in_chroot() {
    if [ $# -eq 0 ]; then
        error "请提供要执行的命令"
    fi
    
    exec_chroot_command "$@"
}

# 安装debian环境
install_debian() {
    log "开始安装Debian环境..."
    
    if [ -e "$DEBIAN_DIR/bin/dpkg" ]; then
        log "Debian环境已存在"
        return 0
    fi
    
    # 运行安装脚本
    bash "$SCRIPT_DIR/chroot/installer_ruri.sh"
    
    log "Debian环境安装完成"
}

# 显示使用帮助
show_usage() {
    cat << EOF
Termux 一键启动脚本 - 整体服务编排器

使用方法:
  $0 [命令]

可用命令:
  start         启动所有服务 (X11 + chroot Linux + sysv初始化系统)
  stop          停止所有服务
  restart       重启所有服务
  status        查看整体服务状态 (X11 + chroot 详细信息)
  enter         进入chroot Linux环境
  exec <命令>   在chroot中执行命令
  install       安装Debian环境
  
示例:
  $0 start                    # 启动完整环境
  $0 enter                    # 进入Linux环境
  $0 exec "apt update"        # 在Linux中执行命令
  $0 status                   # 查看完整状态

快捷别名:
  tstart, tstop, trestart, tstatus, tenter

专用chroot管理 (更多功能):
  bash ~/sh/termux/chroot/cli.sh [start|stop|shell|exec|force-cleanup]
  别名: cstart, cstop, cshell, cexec, cforce

职责分工:
  - termux_all_in_one.sh: 整体服务编排 (X11 + 基础服务 + chroot)
  - cli.sh: 专业chroot容器管理 (挂载、进程、sysv、配置等)
EOF
}

# 主函数
main() {
    local command="${1:-start}"
    
    case "$command" in
        "start")
            check_requirements
            start_base_services
            start_x11
            start_chroot
            log "所有服务启动完成！"
            log "使用 '$0 enter' 进入Linux环境"
            ;;
        "stop")
            stop_all
            ;;
        "restart")
            stop_all
            sleep 2
            main start
            ;;
        "status")
            check_status
            ;;
        "enter")
            enter_chroot
            ;;
        "exec")
            shift
            exec_in_chroot "$@"
            ;;
        "install")
            check_requirements
            install_debian
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            echo "未知命令: $command"
            show_usage
            exit 1
            ;;
    esac
}

# 检查是否直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 