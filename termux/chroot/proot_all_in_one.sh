#!/data/data/com.termux/files/usr/bin/bash

# Termux 一键启动脚本 - Proot-Distro 整合版
# 使用方法: bash ~/sh/termux/chroot/proot_all_in_one.sh [start|stop|restart|status]
# 与 termux_all_in_one.sh 的区别:
#   - 使用 proot-distro 替代 chroot
#   - 不需要 root 权限
#   - 不需要手动 mount/umount 文件系统
#   - 服务通过后台 proot-distro login 启动

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 加载工具函数
. "$PROJECT_ROOT/win-git/toolsinit.sh"
. "$SCRIPT_DIR/proot_cli.sh"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    log "ERROR: $1" >&2
    exit 1
}

# 检查必要的权限和环境 (proot 版本无需 root)
check_requirements() {
    log "检查运行环境..."

    # proot-distro 不需要 root, 但需要 proot-distro 命令
    if ! command -v proot-distro >/dev/null 2>&1; then
        log "安装必要的包: proot-distro"
        pkg install proot-distro -y || error "无法安装 proot-distro"
    fi

    # 检查必要的包 (与 chroot 版本保持一致, X11 仍需要)
    local required_packages=("termux-x11-nightly" "pulseaudio" "virglrenderer-android")
    for pkg in "${required_packages[@]}"; do
        if ! pkg list-installed 2>/dev/null | grep -q "^$pkg/"; then
            log "安装必要的包: $pkg"
            pkg install "$pkg" -y || error "无法安装 $pkg"
        fi
    done

    log "环境检查完成 (proot 模式, 无需 root)"
}

# 启动基础服务 (X11 + pulseaudio, 与 chroot 版本共用)
start_base_services() {
    log "启动基础服务..."

    local services=()
    if [ -f "/sdcard/Download/使用虚拟显卡.txt" ]; then
      log "检测到强制使用虚拟显卡文件，启动virgl服务"
      services=("virgl" "pulseaudio" "x11")
    elif lscpu | grep -q "Oryon"; then
      log "Oryon CPU detected, skipping virgl service startup."
      services=("pulseaudio" "x11")
    else
      services=("virgl" "pulseaudio" "x11")
    fi

    for service in "${services[@]}"; do
        if [ -d "$PREFIX/var/service/$service" ]; then
            log "启动服务: $service"
            sv up "$service" 2>/dev/null || true
        fi
    done
}

# 启动X11服务 (与 chroot 版本一致, X11 在 termux 端)
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
    termux-x11 :1 -ac +extension DPMS -dpi 100 &

    sleep 2
    log "X11服务启动完成"
}

# 启动 proot 容器 (调用 proot_cli.sh 中的函数)
start_proot() {
    log "启动 Proot Linux 容器..."

    if ! start_all_services; then
        error "无法启动 Proot 容器"
    fi

    log "Proot Linux 容器启动完成"
    log "可以使用以下命令进入 Linux 环境:"
    log "  penter 或 pshell"
}

# 停止所有服务
stop_all() {
    log "停止所有服务..."

    # 停止 proot 容器服务 (调用 proot_cli.sh)
    stop_all_services 2>/dev/null || true

    # 停止X11
    sudo killall -9 termux-x11 Xwayland termux-wake-lock 2>/dev/null || true
    sudo pkill -f com.termux.x11 2>/dev/null || true
    am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 2>/dev/null || true

    # 停止sv服务
    local services=()
    if [ -f "/sdcard/Download/使用虚拟显卡.txt" ]; then
      log "检测到强制使用虚拟显卡文件，停止virgl服务"
      services=("virgl" "pulseaudio" "x11")
    elif lscpu | grep -q "Oryon"; then
      log "Oryon CPU detected, skipping virgl service shutdown."
      services=("pulseaudio" "x11")
    else
      services=("virgl" "pulseaudio" "x11")
    fi

    for service in "${services[@]}"; do
        if [ -d "$PREFIX/var/service/$service" ]; then
            sv down "$service" 2>/dev/null || true
        fi
    done

    # 清理临时文件
    clean_tmp

    log "所有服务已停止"
}

# 检查状态 (整合 X11 和 proot 状态)
check_status() {
    echo "=== Termux Proot 整体环境状态 ==="

    echo -n "X11服务: "
    if pgrep -f "termux-x11" >/dev/null; then
        echo "运行中"
    else
        echo "已停止"
    fi

    # 调用 proot_cli.sh 中的详细容器状态检查
    check_container_status

    echo
    echo "=== X11 进程信息 ==="
    echo "X11进程:"
    pgrep -f "termux-x11" | head -5 || echo "  无"

    echo
    echo "=== Proot-Distro 进程信息 ==="
    pgrep -af "proot-distro login" | head -5 || echo "  无"
}

# 进入 proot 环境 (调用 proot_cli.sh 中的函数)
enter_proot() {
    log "进入 Proot Linux 环境..."
    enter_container_shell
}

# 在 proot 中执行命令 (调用 proot_cli.sh 中的函数)
exec_in_proot() {
    if [ $# -eq 0 ]; then
        error "请提供要执行的命令"
    fi

    exec_container_command "$@"
}

# 安装 debian 环境 (proot-distro)
install_debian() {
    log "开始安装 Debian Proot 环境..."

    # 检查是否已安装
    if [ -d "$PROOT_ROOTFS" ] && [ -f "$PROOT_ROOTFS/bin/dpkg" ]; then
        log "Debian Proot 环境已存在"
        return 0
    fi

    # 运行安装脚本 (复用现有的 installer_proot.sh)
    bash "$SCRIPT_DIR/installer_proot.sh"

    log "Debian Proot 环境安装完成"
}

# 安装 proot 环境 (同 install_debian, 别名)
install_proot() {
    log "开始安装 Proot Linux 环境..."
    bash "$SCRIPT_DIR/installer_proot.sh"
    log "Proot Linux 环境安装完成"
}

# 显示使用帮助
show_usage() {
    cat << EOF
Termux 一键启动脚本 - Proot-Distro 整体服务编排器

使用方法:
  \$0 [命令]

可用命令:
  start         启动所有服务 (X11 + Proot Linux 容器)
  stop          停止所有服务
  restart       重启所有服务
  status        查看整体服务状态 (X11 + Proot 详细信息)
  enter         进入 Proot Linux 环境
  exec <命令>   在 Proot 中执行命令
  install       安装 Debian Proot 环境
  init          安装 Proot Linux 环境 (同 install)
  help          显示此帮助

示例:
  \$0 start                    # 启动完整环境
  \$0 enter                    # 进入 Linux 环境
  \$0 exec "apt update"        # 在 Linux 中执行命令
  \$0 status                   # 查看完整状态
  \$0 init                     # 安装 Proot 环境

快捷别名 (建议添加到 setup_aliases.sh):
  pstart, pstop, prestart, pstatus, penter, pinit

专用 Proot 容器管理 (更多功能):
  bash ~/sh/termux/chroot/proot_cli.sh [start|stop|shell|exec|svc|force-cleanup]
  建议别名: pstart, pstop, pshell, pexec, pforce

职责分工:
  - proot_all_in_one.sh: 整体服务编排 (X11 + 基础服务 + Proot 容器)
  - proot_cli.sh: 专业 Proot 容器管理 (服务启停、状态、exec)

与 chroot 版本的区别:
  - 无需 root 权限 (proot 基于用户态 syscall 拦截)
  - 无需手动 mount/umount 文件系统
  - 服务通过后台 proot-distro login 启动
  - 不依赖 sysv init 系统 (服务脚本由 proot_cli.sh 调用)
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
            start_proot
            log "所有服务启动完成！"
            log "使用 '$0 enter' 进入 Linux 环境"
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
            enter_proot
            ;;
        "exec")
            shift
            exec_in_proot "$@"
            ;;
        "install")
            check_requirements
            install_debian
            ;;
        "init")
            check_requirements
            install_proot
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
