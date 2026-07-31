#!/data/data/com.termux/files/usr/bin/bash
# Proot-Distro Linux 容器管理脚本 (对应 cli.sh 的 proot 版本)
# 区别说明:
#   - proot-distro 不需要 root 权限 (基于 syscall 拦截)
#   - proot-distro 不需要手动 mount/umount (自动绑定 /dev /proc /sys /sdcard)
#   - proot-distro 每个 login 是独立会话, 无法依赖 sysv init 持久化服务
#   - 服务通过后台启动 `proot-distro login <distro> -- <cmd> &` 实现

PREFIX=/data/data/com.termux/files/usr

# Proot-Distro 配置
DISTRO_NAME="${DISTRO_NAME:-debian}"
DISTRO_OLD_NAME="${DISTRO_OLD_NAME:-debian-oldstable}"
PROOT_CMD="proot-distro"
# proot-distro 默认 rootfs 安装位置
PROOT_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/${DISTRO_NAME}"

# 容器内部服务启动脚本 (由 server_configure.sh 安装)
CONTAINER_SERVICES_SCRIPT="/usr/local/bin/proot-services.sh"

# Termux 端 PID/日志目录
PROOT_RUN_DIR="${TMPDIR:-$PREFIX/tmp}/proot-${DISTRO_NAME}"
mkdir -p "$PROOT_RUN_DIR" 2>/dev/null

# 需要管理的关键服务 (服务名:进程关键字:启动命令)
# 启动命令为空表示使用 CONTAINER_SERVICES_SCRIPT 启动
PROOT_SERVICES=(
  "sshd:sshd:/usr/sbin/sshd"
  "dbus:dbus-daemon:/usr/bin/dbus-daemon --system --fork"
  "vnc:Xvnc:/usr/bin/vncserver :1"
  "novnc:novnc_proxy:/usr/local/noVNC/utils/novnc_proxy --vnc 127.0.0.1:5901 --listen 10086"
)

# 网络命名空间不需要,proot 共享 host 网络
# DISPLAY 由 termux-x11 提供, 但 proot 容器内部需要 export DISPLAY=:1
PROOT_ENV="DISPLAY=:1 PULSE_SERVER=127.0.0.1 GDK_DPI_SCALING=1"
PROOT_BINDS="--bind /dev --bind /proc --bind /sys --bind /dev/urandom --bind /sdcard"

# 用户配置
INIT_USER="${INIT_USER:-root}"

# 日志函数
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
  log "ERROR: $1" >&2
  exit 1
}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

# 检查 proot-distro 是否安装
check_proot_installed() {
  if ! command -v $PROOT_CMD >/dev/null 2>&1; then
    log_error "未找到 $PROOT_CMD, 请先安装: pkg install proot-distro"
    return 1
  fi
  return 0
}

# 检查 distro 是否已安装
check_distro_installed() {
  check_proot_installed || return 1

  # 多个候选位置
  local distro_paths=(
    "$PROOT_ROOTFS"
    "$PREFIX/var/lib/proot-distro/installed-rootfs/${DISTRO_OLD_NAME}"
  )

  local debug_info=""
  for distro_path in "${distro_paths[@]}"; do
    debug_info="${debug_info}检查路径: $distro_path\n"
    if [ -d "$distro_path" ]; then
      debug_info="${debug_info}  目录存在: ✓\n"
      local found=false
      if [ -f "$distro_path/bin/dpkg" ] || [ -f "$distro_path/usr/bin/dpkg" ]; then
        debug_info="${debug_info}  dpkg: ✓\n"
        found=true
      elif [ -f "$distro_path/etc/debian_version" ]; then
        debug_info="${debug_info}  /etc/debian_version: ✓\n"
        found=true
      fi
      if [ "$found" = true ]; then
        PROOT_ROOTFS="$distro_path"
        echo -e "找到 ${DISTRO_NAME} 安装: $PROOT_ROOTFS\n$debug_info" >&2
        return 0
      fi
    else
      debug_info="${debug_info}  目录存在: ✗\n"
    fi
  done

  echo -e "未找到 ${DISTRO_NAME} 安装!\n$debug_info\n请先运行: proot-distro install ${DISTRO_NAME}" >&2
  return 1
}

# 在容器内执行命令
# 用法: proot_exec [-u user] <command...>
proot_exec() {
  local user="$INIT_USER"
  if [ "$1" = "-u" ]; then
    user="$2"
    shift 2
  fi
  # 使用 proot-distro login 执行命令
  # 注意: --termux-home 不使用, --shared-tmp 自动启用
  $PROOT_CMD login "$DISTRO_NAME" --user "$user" -- env $PROOT_ENV "$@"
}

# 在容器内执行 shell 脚本 (bash -c)
proot_exec_bash() {
  local user="$INIT_USER"
  if [ "$1" = "-u" ]; then
    user="$2"
    shift 2
  fi
  proot_exec -u "$user" /bin/bash -c "$*"
}

# 启动单个服务 (后台)
# 用法: start_service <name> <pattern> <command>
start_service() {
  local name="$1"
  local pattern="$2"
  local cmd="$3"
  local pidfile="$PROOT_RUN_DIR/${name}.pid"
  local logfile="$PROOT_RUN_DIR/${name}.log"

  # 检查是否已运行
  if [ -f "$pidfile" ]; then
    local old_pid=$(cat "$pidfile" 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      # 进一步检查进程是否匹配
      if pgrep -f "$pattern" >/dev/null 2>&1; then
        log_info "$name 已在运行 (pid=$old_pid)"
        return 0
      fi
    fi
    rm -f "$pidfile"
  fi

  log_debug "启动服务: $name ($cmd)"
  # 使用 nohup + & 在后台运行 proot-distro login
  nohup $PROOT_CMD login "$DISTRO_NAME" --user "$INIT_USER" \
    -- env $PROOT_ENV /bin/bash -c "$cmd" >"$logfile" 2>&1 &
  local pid=$!
  echo "$pid" >"$pidfile"

  # 等待启动
  sleep 1
  if kill -0 "$pid" 2>/dev/null; then
    log_info "$name 启动成功 (pid=$pid)"
    return 0
  else
    log_warn "$name 启动失败, 查看日志: $logfile"
    return 1
  fi
}

# 停止单个服务
stop_service() {
  local name="$1"
  local pattern="$2"
  local pidfile="$PROOT_RUN_DIR/${name}.pid"

  local stopped_any=false

  # 1. 通过 pidfile 停止
  if [ -f "$pidfile" ]; then
    local pid=$(cat "$pidfile" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      log_debug "停止 $name (pid=$pid)"
      kill -TERM "$pid" 2>/dev/null || true
      sleep 1
      kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
      stopped_any=true
    fi
    rm -f "$pidfile"
  fi

  # 2. 通过 pattern 匹配残留进程
  local pids=$(pgrep -f "$pattern" 2>/dev/null || true)
  if [ -n "$pids" ]; then
    log_debug "清理 $name 残留进程: $pids"
    for pid in $pids; do
      sudo kill -KILL "$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
    done
    stopped_any=true
  fi

  if [ "$stopped_any" = true ]; then
    log_info "$name 已停止"
  else
    log_info "$name 未运行"
  fi
  return 0
}

# 检查服务状态
check_service_status() {
  local name="$1"
  local pattern="$2"
  local pidfile="$PROOT_RUN_DIR/${name}.pid"

  if [ -f "$pidfile" ]; then
    local pid=$(cat "$pidfile" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo -e "  ${GREEN}●${NC} $name (pid=$pid)"
      return 0
    fi
  fi

  if pgrep -f "$pattern" >/dev/null 2>&1; then
    local pid=$(pgrep -f "$pattern" | head -1)
    echo -e "  ${YELLOW}●${NC} $name (运行中, pidfile 缺失, pid=$pid)"
    return 0
  fi

  echo -e "  ${RED}○${NC} $name (已停止)"
  return 1
}

# 启动所有服务 (使用容器内服务脚本)
start_all_services() {
  log_info "启动 Proot ${DISTRO_NAME} 容器服务..."

  if ! check_distro_installed; then
    return 1
  fi

  # 方式 1: 优先使用容器内的统一服务脚本 (推荐)
  if proot_exec test -x "$CONTAINER_SERVICES_SCRIPT" 2>/dev/null; then
    log_debug "使用容器内服务脚本: $CONTAINER_SERVICES_SCRIPT"
    nohup $PROOT_CMD login "$DISTRO_NAME" --user "$INIT_USER" \
      -- env $PROOT_ENV "$CONTAINER_SERVICES_SCRIPT" start \
      >"$PROOT_RUN_DIR/services.log" 2>&1 &
    local pid=$!
    echo "$pid" >"$PROOT_RUN_DIR/services.pid"
    sleep 2
    log_info "服务脚本已启动 (pid=$pid)"
    return 0
  fi

  # 方式 2: 逐个启动服务 (后备方案)
  log_warn "容器内未找到 $CONTAINER_SERVICES_SCRIPT, 使用逐个启动方式"
  local svc name pattern cmd
  for svc in "${PROOT_SERVICES[@]}"; do
    IFS=':' read -r name pattern cmd <<<"$svc"
    [ -n "$cmd" ] || continue
    start_service "$name" "$pattern" "$cmd" || log_warn "$name 启动失败"
  done

  return 0
}

# 停止所有服务
stop_all_services() {
  log_info "停止 Proot ${DISTRO_NAME} 容器服务..."

  # 1. 调用容器内服务脚本的 stop
  if proot_exec test -x "$CONTAINER_SERVICES_SCRIPT" 2>/dev/null; then
    log_debug "调用容器内服务脚本 stop"
    proot_exec "$CONTAINER_SERVICES_SCRIPT" stop 2>/dev/null || true
  fi

  # 2. 逐个停止服务 (清理残留)
  local svc name pattern cmd
  for svc in "${PROOT_SERVICES[@]}"; do
    IFS=':' read -r name pattern cmd <<<"$svc"
    stop_service "$name" "$pattern" || true
  done

  # 3. 终止 services.pid 主进程
  if [ -f "$PROOT_RUN_DIR/services.pid" ]; then
    local pid=$(cat "$PROOT_RUN_DIR/services.pid" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
    rm -f "$PROOT_RUN_DIR/services.pid"
  fi

  log_info "所有服务已停止"
  return 0
}

# 检查容器是否在运行 (任一服务运行即认为运行)
container_running() {
  local svc name pattern
  for svc in "${PROOT_SERVICES[@]}"; do
    IFS=':' read -r name pattern _ <<<"$svc"
    if pgrep -f "$pattern" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

# 检查容器状态 (详细)
check_container_status() {
  echo -e "${BLUE}=== Proot ${DISTRO_NAME} 容器状态 ===${NC}"

  # 检查 distro 安装
  if check_distro_installed 2>/dev/null; then
    echo -e "Distro 安装: ${GREEN}已安装${NC} ($PROOT_ROOTFS)"
  else
    echo -e "Distro 安装: ${RED}未安装${NC}"
    return
  fi

  # 列出 proot-distro 已知 distro
  if $PROOT_CMD list 2>/dev/null | grep -q "^\* ${DISTRO_NAME}"; then
    echo -e "Distro 注册: ${GREEN}已注册${NC}"
  fi

  # 检查服务运行状态
  echo ""
  echo -e "${BLUE}服务状态:${NC}"
  local any_running=false
  local svc name pattern
  for svc in "${PROOT_SERVICES[@]}"; do
    IFS=':' read -r name pattern _ <<<"$svc"
    if check_service_status "$name" "$pattern"; then
      any_running=true
    fi
  done

  echo ""
  if [ "$any_running" = true ]; then
    echo -e "容器状态: ${GREEN}运行中${NC}"
  else
    echo -e "容器状态: ${RED}已停止${NC}"
  fi

  # 显示运行目录
  echo ""
  echo -e "${BLUE}运行时文件:${NC} $PROOT_RUN_DIR"
  if [ -d "$PROOT_RUN_DIR" ]; then
    ls -la "$PROOT_RUN_DIR" 2>/dev/null | tail -n +2 | head -20
  fi
}

# 进入容器 shell
enter_container_shell() {
  if ! check_distro_installed; then
    return 1
  fi
  log_info "进入 Proot ${DISTRO_NAME} 环境..."
  $PROOT_CMD login "$DISTRO_NAME" --user "$INIT_USER"
}

# 在容器中执行命令
exec_container_command() {
  local command="$*"
  if [ -z "$command" ]; then
    log_error "请提供要执行的命令"
    echo "  使用: exec_container_command <命令>"
    return 1
  fi
  if ! check_distro_installed; then
    return 1
  fi
  log_info "在 Proot 容器中执行: $command"
  proot_exec /bin/bash -c "$command"
}

# 强制清理所有 proot 容器进程
force_cleanup() {
  log_warn "强制清理所有 Proot ${DISTRO_NAME} 进程..."

  # 杀掉所有 proot-distro login 进程
  pkill -KILL -f "proot-distro login ${DISTRO_NAME}" 2>/dev/null || true

  # 杀掉所有服务进程
  local svc name pattern
  for svc in "${PROOT_SERVICES[@]}"; do
    IFS=':' read -r name pattern _ <<<"$svc"
    pkill -KILL -f "$pattern" 2>/dev/null || true
  done

  # 清理 pid 文件
  rm -rf "$PROOT_RUN_DIR"/*.pid 2>/dev/null
  log_info "强制清理完成"
}

# 安装 distro
install_distro() {
  log_info "安装 ${DISTRO_NAME} via proot-distro..."
  check_proot_installed || return 1
  $PROOT_CMD install "$DISTRO_NAME"
}

# 重启容器
restart_container() {
  log_info "重启 Proot 容器..."
  stop_all_services
  sleep 2
  start_all_services
}

# 命令行接口
proot_manager_cli() {
  case "${1:-help}" in
    start | s)
      start_all_services
      ;;
    stop | st)
      stop_all_services
      ;;
    restart | r)
      restart_container
      ;;
    status | stat)
      check_container_status
      ;;
    shell | sh)
      enter_container_shell
      ;;
    enter | e)
      enter_container_shell
      ;;
    exec)
      shift
      exec_container_command "$@"
      ;;
    install | i)
      install_distro
      ;;
    force-cleanup | fc)
      log_warn "这是应急清理功能!"
      read -p "确定要强制清理所有 ${DISTRO_NAME} 进程吗？(y/N): " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        force_cleanup
      else
        log_info "取消强制清理"
      fi
      ;;
    svc)
      # 单个服务管理: proot_cli.sh svc <start|stop|status> <name>
      local action="${2:-status}"
      local svc_name="${3:-}"
      if [ -z "$svc_name" ]; then
        echo "用法: $0 svc <start|stop|status> <sshd|dbus|vnc|novnc>"
        return 1
      fi
      local svc name pattern cmd
      for svc in "${PROOT_SERVICES[@]}"; do
        IFS=':' read -r name pattern cmd <<<"$svc"
        if [ "$name" = "$svc_name" ]; then
          case "$action" in
            start) start_service "$name" "$pattern" "$cmd" ;;
            stop)  stop_service "$name" "$pattern" ;;
            status) check_service_status "$name" "$pattern" ;;
            *) echo "未知动作: $action" ;;
          esac
          return $?
        fi
      done
      log_error "未找到服务: $svc_name"
      return 1
      ;;
    help | h | *)
      cat <<EOF
${BLUE}Proot-Distro ${DISTRO_NAME} 容器管理${NC}

${GREEN}基础操作:${NC}
  ${YELLOW}start${NC}         启动容器服务 (sshd/dbus/vnc/novnc)
  ${YELLOW}stop${NC}          停止容器服务
  ${YELLOW}restart${NC}       重启容器
  ${YELLOW}status${NC}        查看容器状态

${GREEN}交互操作:${NC}
  ${YELLOW}shell${NC}/${YELLOW}enter${NC}    进入容器 shell
  ${YELLOW}exec${NC} <cmd>    在容器中执行命令

${GREEN}服务管理:${NC}
  ${YELLOW}svc${NC} <action> <name>  单服务管理 (start|stop|status)
                  可用服务: sshd, dbus, vnc, novnc

${GREEN}安装/清理:${NC}
  ${YELLOW}install${NC}      安装 ${DISTRO_NAME} distro
  ${YELLOW}force-cleanup${NC} 强制清理所有 proot 进程

${GREEN}常用示例:${NC}
  bash ~/sh/termux/chroot/proot_cli.sh start
  bash ~/sh/termux/chroot/proot_cli.sh shell
  bash ~/sh/termux/chroot/proot_cli.sh exec "apt update"
  bash ~/sh/termux/chroot/proot_cli.sh svc start sshd
  bash ~/sh/termux/chroot/proot_cli.sh status

${GREEN}环境变量:${NC}
  ${YELLOW}DISTRO_NAME${NC}=${DISTRO_NAME}    - 目标 distro 名
  ${YELLOW}INIT_USER${NC}=${INIT_USER}        - 登录用户
  ${YELLOW}PROOT_ENV${NC}=${PROOT_ENV}        - 容器内环境变量
EOF
      ;;
  esac
}

# 如果直接运行此脚本，则调用命令行接口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  proot_manager_cli "$@"
fi
