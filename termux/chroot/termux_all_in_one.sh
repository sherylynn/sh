#!/data/data/com.termux/files/usr/bin/bash

# Termux 一键启动脚本 - 整合所有功能
# 使用方法: bash ~/sh/termux/chroot/termux_all_in_one.sh [start|stop|restart|status]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 日志函数
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
  log "ERROR: $1" >&2
  exit 1
}

# ERR trap: set -e 静默退出时打印失败位置, 便于定位
trap 'log "ERR: 命令失败 行号=$LINENO 命令=\$BASH_COMMAND" >&2' ERR

# 加载工具函数
log "加载 toolsinit.sh..."
. "$PROJECT_ROOT/win-git/toolsinit.sh"
# cli.sh 含预期的非零返回 (sudo test -f ... && ..., detect_distro_rootfs return 1)
# 临时关闭 set -e 避免 source 时误退出
log "加载 cli.sh..."
trap - ERR
set +e
. "$SCRIPT_DIR/cli.sh"
set -e
trap 'log "ERR: 命令失败 行号=$LINENO 命令=\$BASH_COMMAND" >&2' ERR
log "cli.sh 加载完成, DEBIAN_DIR=$DEBIAN_DIR"

# 检查必要的权限和环境
check_requirements() {
  log "检查运行环境..."

  # 检查root权限 (依次尝试 sudo / tsu / su, 打印命中方式)
  local root_method=""
  if [ "$(id -u 2>/dev/null)" = "0" ]; then
    root_method="uid0"
  elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    root_method="sudo-nopass"
  elif command -v tsu >/dev/null 2>&1 && tsu -c true 2>/dev/null; then
    root_method="tsu"
  fi
  if [ -z "$root_method" ]; then
    # 最后兜底: 交互式 sudo (原行为, 可能阻塞等密码)
    if sudo true 2>/dev/null; then
      root_method="sudo-interactive"
    fi
  fi
  if [ -z "$root_method" ]; then
    error "需要root权限，请确保已获取root权限 (尝试过 uid0/sudo-n/tsu/sudo)"
  fi
  log "root 权限检测通过 (方式: $root_method)"

  # 启动阶段只验证关键命令，不执行 pkg；依赖统一由 installer_proot.sh 安装。
  local required_command
  for required_command in sv; do
    command -v "$required_command" >/dev/null 2>&1 ||
      error "缺少命令 $required_command，请先运行 installer_proot.sh"
  done

  log "环境检查完成"
}

# 启动基础服务
start_base_services() {
  log "启动基础服务..."

  # 启动必要的sv服务
  local services=()
  if [ -f "/sdcard/Download/使用虚拟显卡.txt" ]; then
    log "检测到强制使用虚拟显卡文件，启动virgl服务"
    services=("virgl" "pulseaudio")
  elif lscpu | grep -q "Oryon"; then
    log "Oryon CPU detected, skipping virgl service startup."
    services=("pulseaudio")
  else
    services=("virgl" "pulseaudio")
  fi

  # native Wayland compositor 由 NewHome 自身拥有；Termux 用户阶段只维护
  # 音频等基础服务，不再启动独立 Termux:X11 display server。
  if [ "${TERMUX_SPLIT_USER_PHASE:-0}" = "1" ]; then
    services=("pulseaudio")
  fi

  for service in "${services[@]}"; do
    if [ -d "$PREFIX/var/service/$service" ]; then
      log "启动服务: $service"
      sv up "$PREFIX/var/service/$service" 2>/dev/null || true
    fi
  done
}

# NewHome native Wayland compositor owns display lifecycle.
# XWayland is compositor-internal compatibility for legacy X11 clients and is not
# started/stopped by Termux orchestration.

# 启动chroot linux (调用cli.sh中的函数)
start_chroot() {
  log "启动chroot Linux环境..."
  log "容器 rootfs 路径: $DEBIAN_DIR"
  log "挂载点路径: $CHROOT_DIR"

  # 直接调用cli.sh中的完整实现
  if ! start_chroot_container; then
    error "无法启动chroot环境"
  fi

  log "Chroot Linux环境启动完成 (包括初始化系统服务)"
  log "可以使用以下命令进入Linux环境:"
  log "  tenter 或 cshell"
}

# 在 rc3 启动 noVNC 服务前，把 Termux checkout 中的运行脚本同步进 rootfs。
# 这样普通 tstart 和 GhostLock 分阶段入口都会使用同一版本。
sync_remote_desktop_scripts() {
  local destination_dir
  destination_dir="$DEBIAN_DIR/root/sh/win-git"
  sudo mkdir -p "$destination_dir"
  if [ -f "$PROJECT_ROOT/win-git/server_noVNC.sh" ]; then
    sudo cp "$PROJECT_ROOT/win-git/server_noVNC.sh" "$destination_dir/server_noVNC.sh"
    sudo chmod 755 "$destination_dir/server_noVNC.sh"
  fi
}

wait_remote_desktop_services() {
  local wait_step backend_state backend
  backend_state="$DEBIAN_DIR/root/.vnc/novnc-backend.env"
  for wait_step in {1..60}; do
    backend=$(sudo sed -n 's/^backend=//p' "$backend_state" 2>/dev/null | head -1)
    if [ "$backend" = "native" ] &&
      pgrep -f 'newhome_websockify.py' >/dev/null 2>&1 &&
      { grep -qE ':2766 .* 0A ' /proc/net/tcp 2>/dev/null ||
        grep -qE ':2766 .* 0A ' /proc/net/tcp6 2>/dev/null; }; then
      log "远程桌面健康检查通过: NewHome native RFB -> noVNC=:10086"
      return 0
    fi
    sleep 0.5
  done

  log "ERROR: NewHome native RFB/noVNC 健康检查失败 (backend=${backend:-unknown})" >&2
  sudo tail -120 "$DEBIAN_DIR/root/.vnc/server-noVNC-startup.log" 2>/dev/null || true
  sudo tail -80 "$DEBIAN_DIR/root/.vnc/novnc-proxy.log" 2>/dev/null || true
  return 1
}

# 停止所有服务
stop_all() {
  log "停止所有服务..."

  # 停止chroot容器 (调用cli.sh中的完整实现)
  stop_chroot_container 2>/dev/null || true

  # 停止sv服务
  local services=()
  if [ -f "/sdcard/Download/使用虚拟显卡.txt" ]; then
    log "检测到强制使用虚拟显卡文件，停止virgl服务"
    services=("virgl" "pulseaudio")
  elif lscpu | grep -q "Oryon"; then
    log "Oryon CPU detected, skipping virgl service shutdown."
    services=("pulseaudio")
  else
    services=("virgl" "pulseaudio")
  fi

  for service in "${services[@]}"; do
    if [ -d "$PREFIX/var/service/$service" ]; then
      sv down "$PREFIX/var/service/$service" 2>/dev/null || true
    fi
  done

  # 清理进程
  kill_need 2>/dev/null || true
  clean_tmp

  log "所有服务已停止"
}

# 只停止属于 Termux 用户的基础服务；显示生命周期由 NewHome compositor 管理。
stop_user_services() {
  log "停止 Termux 用户基础服务..."

  local service
  for service in pulseaudio virgl; do
    if [ -d "$PREFIX/var/service/$service" ]; then
      sv down "$PREFIX/var/service/$service" 2>/dev/null || true
    fi
  done
  log "Termux 用户服务已停止"
}

# 检查状态
check_status() {
  echo "=== Termux 整体环境状态 ==="
  echo "显示服务: NewHome native Wayland compositor（Android 侧持有）"
  echo "XWayland: 仅由 compositor 按需管理，不由本脚本启停"

  # 调用cli.sh中的详细chroot状态检查
  check_chroot_status
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
  bash "$SCRIPT_DIR/chroot/installer_proot.sh"

  log "Debian环境安装完成"
}

# 安装proot环境
install_proot() {
  log "开始安装Proot Linux环境..."

  # 运行安装脚本
  bash "$SCRIPT_DIR/chroot/installer_proot.sh"

  log "Proot Linux环境安装完成"
}

# 显示使用帮助
show_usage() {
  cat <<EOF
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
  init          安装Proot Linux环境

示例:
  $0 start                    # 启动完整环境
  $0 enter                    # 进入Linux环境
  $0 exec "apt update"        # 在Linux中执行命令
  $0 status                   # 查看完整状态
  $0 init                     # 安装Proot环境

快捷别名:
  tstart, tstop, trestart, tstatus, tenter, tinit

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
      # NewHome native Wayland compositor is the sole desktop owner. XWayland is
      # spawned/managed by that compositor only when legacy X11 clients need it.
      sync_remote_desktop_scripts
      start_chroot
      wait_remote_desktop_services
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
    "init")
      check_requirements
      install_proot
      ;;
    "help" | "-h" | "--help")
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
