#!/data/data/com.termux/files/usr/bin/bash
# Proot-Distro Linux 容器管理脚本 (对应 cli.sh 的 proot 版本)
#
# 架构: 对齐 chroot 版 cli.sh 的 sysv init 机制
#   - start_init: 遍历 /etc/rc${INIT_LEVEL}.d/S* 执行 start (与 cli.sh 一致)
#   - stop_init:  遍历 /etc/rc6.d/K* 执行 stop + 杀常驻 login 进程
#   - 服务清单由容器内 init.d/rc.d 决定 (init_d_noVNC.sh + apt 包 postinst 生成),
#     不再硬编码 PROOT_SERVICES, 不依赖 proot-services.sh 中间层
#
# proot 与 chroot 的差异:
#   - proot 不需要 root/mount (自动绑定 /dev /proc /sys)
#   - proot 每次 login 是独立会话, login 退出会杀掉它 trace 的子进程,
#     因此 start_init 用一个常驻 login 进程遍历启动服务后 hold 住会话, 让 daemon 常驻

PREFIX=/data/data/com.termux/files/usr

# Proot-Distro 配置
DISTRO_NAME="${DISTRO_NAME:-debian}"
DISTRO_OLD_NAME="${DISTRO_OLD_NAME:-debian-oldstable}"
PROOT_CMD="proot-distro"

# 检测 distro 的实际安装路径 (兼容 proot-distro 新旧版本)
# 旧版本: installed-rootfs/<distro>
# 新版本(5.1): containers/<distro>/rootfs  (rootfs 在子目录, 旁边有 manifest.json)
# 用法: detect_proot_rootfs [distro_name]
# 返回: 找到则输出路径并返回 0; 未找到返回旧版默认路径并返回 1
detect_proot_rootfs() {
  local distro="${1:-$DISTRO_NAME}"
  local candidates=(
    "$PREFIX/var/lib/proot-distro/installed-rootfs/$distro"
    "$PREFIX/var/lib/proot-distro/containers/$distro/rootfs"
  )
  for path in "${candidates[@]}"; do
    if [ -d "$path" ] && {
      [ -f "$path/bin/dpkg" ] || [ -f "$path/usr/bin/dpkg" ] || [ -f "$path/etc/debian_version" ]
    }; then
      echo "$path"
      return 0
    fi
  done
  echo "$PREFIX/var/lib/proot-distro/installed-rootfs/$distro"
  return 1
}

# proot-distro rootfs 安装位置 (加载时自动检测, 兼容新旧路径)
PROOT_ROOTFS="$(detect_proot_rootfs)"

# Termux 端 PID/日志目录
PROOT_RUN_DIR="${TMPDIR:-$PREFIX/tmp}/proot-${DISTRO_NAME}"
mkdir -p "$PROOT_RUN_DIR" 2>/dev/null

# init 级别 (对齐 cli.sh: 3=多用户文本模式)
INIT_LEVEL="${INIT_LEVEL:-3}"

# 容器内环境变量 (对齐 cli.sh chroot_exec 的 PATH 重置)
# PATH 显式重置为容器标准路径: proot-distro 默认会把 termux 的
#   /data/data/com.termux/files/usr/bin 挂进容器, 导致 python/node 等误用
#   termux 版本 (server_configure.sh 里 apt install 的程序会被屏蔽)
PROOT_ENV="DISPLAY=:1 PULSE_SERVER=127.0.0.1 GDK_DPI_SCALING=1 PROOT_CONTAINER=1 PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# proot-distro login 通用参数 (所有 login 调用共用, 保证行为一致)
# --isolated:       不挂载 termux 的 /data/data/com.termux (含 termux 的 python/node 等),
#                   从源头消除 PATH 污染 —— 否则交互式 shell 里 which python 指向 termux 版本
# --bind /sdcard:   --isolated 会去掉默认 /sdcard 挂载, 这里显式恢复 (server_configure.sh 依赖)
# --shared-tmp:     共享 /tmp —— dbus socket / vnc 锁文件 / X11 socket 都在 /tmp,
#                   不共享则容器内服务与 termux 端 termux-x11 无法互通
# --redirect-ports: 低端口重定向 —— proot 无法绑定 <1024 端口, sshd(22)->2022
# 说明: /dev /proc /sys 由 proot-distro 默认挂载 (即使 --isolated 也保留)
PROOT_LOGIN_OPTS="--isolated --bind /sdcard --shared-tmp --redirect-ports"

# 用户配置
INIT_USER="${INIT_USER:-root}"
# 是否异步启动服务 (对齐 cli.sh INIT_ASYNC: true=并行, false=串行)
[ -n "${INIT_ASYNC}" ] || INIT_ASYNC="true"

# 日志函数
log()       { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
error()     { log "ERROR: $1" >&2; exit 1; }

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
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

  # 候选: 新旧路径 × 主/旧版 distro 名
  local distro_paths=(
    "$PREFIX/var/lib/proot-distro/installed-rootfs/${DISTRO_NAME}"
    "$PREFIX/var/lib/proot-distro/containers/${DISTRO_NAME}/rootfs"
    "$PREFIX/var/lib/proot-distro/installed-rootfs/${DISTRO_OLD_NAME}"
    "$PREFIX/var/lib/proot-distro/containers/${DISTRO_OLD_NAME}/rootfs"
  )

  local debug_info=""
  for distro_path in "${distro_paths[@]}"; do
    debug_info="${debug_info}检查路径: $distro_path\n"
    if [ -d "$distro_path" ]; then
      debug_info="${debug_info}  目录存在: ✓\n"
      local found=false
      if [ -f "$distro_path/bin/dpkg" ] || [ -f "$distro_path/usr/bin/dpkg" ]; then
        debug_info="${debug_info}  dpkg: ✓\n"; found=true
      elif [ -f "$distro_path/etc/debian_version" ]; then
        debug_info="${debug_info}  /etc/debian_version: ✓\n"; found=true
      fi
      if [ "$found" = true ]; then
        PROOT_ROOTFS="$distro_path"
        echo -e "找到安装: $PROOT_ROOTFS\n$debug_info" >&2
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
  # 通用参数由 $PROOT_LOGIN_OPTS 统一控制 (--isolated --bind /sdcard --shared-tmp --redirect-ports)
  $PROOT_CMD login "$DISTRO_NAME" --user "$user" $PROOT_LOGIN_OPTS \
    -- env $PROOT_ENV "$@"
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

# === sysv init 服务管理 (对齐 cli.sh start_init / stop_init) ===

# 列出 rc${INIT_LEVEL}.d/S* 服务 (宿主端路径检查, 不进容器)
list_init_services() {
  local level="${1:-$INIT_LEVEL}"
  local prefix="${2:-S}"
  local rc_dir="${PROOT_ROOTFS}/etc/rc${level}.d"
  [ -d "$rc_dir" ] || return 1
  ls "$rc_dir/" 2>/dev/null | grep "^${prefix}" | sort
}

# 启动 init 服务: 遍历 /etc/rc${INIT_LEVEL}.d/S* 执行 start (对齐 cli.sh start_init)
# proot 特性: 用一个常驻 login 进程托管所有服务
#   proot login 退出会杀掉它 trace 的子进程 (sshd/dbus daemon 也会被回收),
#   因此遍历启动后用 while sleep hold 住会话, 让 daemon 常驻
start_init() {
  check_distro_installed || return 1

  local rc_dir="${PROOT_ROOTFS}/etc/rc${INIT_LEVEL}.d"
  if [ ! -d "$rc_dir" ]; then
    log_warn "未找到 rc${INIT_LEVEL}.d ($rc_dir)"
    log_warn "提示: 在容器内运行 ~/sh/win-git/server_configure.sh"
    log_warn "      (它通过 init_d_noVNC.sh + apt 包 postinst 生成 rc.d 链接)"
    return 1
  fi

  local services=$(list_init_services "$INIT_LEVEL" "S")
  if [ -z "$services" ]; then
    log_warn "rc${INIT_LEVEL}.d 无 S* 服务脚本, 无需启动"
    return 1
  fi

  local pidfile="$PROOT_RUN_DIR/init.pid"
  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; then
    log_info "init 服务已在运行 (pid=$(cat "$pidfile"))"
    return 0
  fi

  log_info "启动 init 服务 (级别 $INIT_LEVEL): $(echo $services | tr '\n' ' ')"

  # 单个常驻 login: 容器内遍历 rc3.d/S* start, 然后 hold 住会话保活
  # 异步 (&): 对齐 cli.sh INIT_ASYNC, 每个服务 start 不阻塞后续
  # PROOT_INIT_SESSION=1: 标记本 login 为 init 会话, stop_init 据此精确清理 (不误杀用户 shell)
  local async_op='"$item" start &'
  [ "$INIT_ASYNC" = "true" ] || async_op='"$item" start'

  nohup $PROOT_CMD login "$DISTRO_NAME" --user "$INIT_USER" $PROOT_LOGIN_OPTS \
    -- env $PROOT_ENV PROOT_INIT_SESSION=1 /bin/sh -c '
      for item in /etc/rc'"$INIT_LEVEL"'.d/S*; do
        [ -x "$item" ] || continue
        '"$async_op"'
      done
      while :; do sleep 3600; done
    ' >"$PROOT_RUN_DIR/init.log" 2>&1 &
  local pid=$!
  echo "$pid" >"$pidfile"

  sleep 2
  if kill -0 "$pid" 2>/dev/null; then
    log_info "init 服务已启动 (pid=$pid, 日志: $PROOT_RUN_DIR/init.log)"
  else
    log_warn "init 服务启动失败, 查看日志: $PROOT_RUN_DIR/init.log"
    tail -20 "$PROOT_RUN_DIR/init.log" 2>/dev/null
  fi
  return 0
}

# 停止 init 服务: 杀常驻 login 进程 + 遍历 rc6.d/K* stop (对齐 cli.sh stop_init)
stop_init() {
  local pidfile="$PROOT_RUN_DIR/init.pid"
  local stopped=false

  # 1. 调用容器内 rc6.d/K* stop (对齐 cli.sh stop_init, 关机级别)
  if check_distro_installed 2>/dev/null; then
    local rc6_dir="${PROOT_ROOTFS}/etc/rc6.d"
    if [ -d "$rc6_dir" ]; then
      local kill_services=$(ls "$rc6_dir/" 2>/dev/null | grep '^K' | sort)
      if [ -n "$kill_services" ]; then
        log_debug "执行 rc6.d/K* stop..."
        local item
        for item in $kill_services; do
          proot_exec "/etc/rc6.d/$item" stop 2>/dev/null || true
        done
      fi
    fi
  fi

  # 2. 杀常驻 login 进程 (proot 退出会连带杀掉它 trace 的 daemon)
  if [ -f "$pidfile" ]; then
    local pid=$(cat "$pidfile" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      log_debug "停止 init 进程 (pid=$pid)"
      kill -TERM "$pid" 2>/dev/null || true
      sleep 1
      kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
      stopped=true
    fi
    rm -f "$pidfile"
  fi

  # 3. 清理带 PROOT_INIT_SESSION 标记的残留 login (精确匹配, 不误杀用户交互 shell)
  pkill -KILL -f "PROOT_INIT_SESSION" 2>/dev/null && stopped=true

  [ "$stopped" = true ] && log_info "init 服务已停止" || log_info "init 服务未运行"
  return 0
}

# 检查容器是否在运行 (init.pid 存活)
container_running() {
  local pidfile="$PROOT_RUN_DIR/init.pid"
  [ -f "$pidfile" ] || return 1
  local pid=$(cat "$pidfile" 2>/dev/null)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

# 容器状态 (对齐 cli.sh 的初始化系统状态展示)
check_container_status() {
  echo -e "${BLUE}=== Proot ${DISTRO_NAME} 容器状态 ===${NC}"

  if check_distro_installed 2>/dev/null; then
    echo -e "Distro 安装: ${GREEN}已安装${NC} ($PROOT_ROOTFS)"
  else
    echo -e "Distro 安装: ${RED}未安装${NC}"
    return
  fi

  # init 进程状态
  echo ""
  echo -e "${BLUE}init 进程:${NC}"
  local pidfile="$PROOT_RUN_DIR/init.pid"
  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null; then
    echo -e "  ${GREEN}●${NC} init (pid=$(cat "$pidfile"))"
  else
    echo -e "  ${RED}○${NC} init (已停止)"
  fi

  # rc${INIT_LEVEL}.d 服务清单 (与 cli.sh 的初始化系统展示一致)
  echo ""
  echo -e "${BLUE}初始化系统 (级别 ${INIT_LEVEL}):${NC}"
  local rc_dir="${PROOT_ROOTFS}/etc/rc${INIT_LEVEL}.d"
  if [ -d "$rc_dir" ]; then
    local services=$(list_init_services "$INIT_LEVEL" "S")
    if [ -n "$services" ]; then
      local count=$(echo "$services" | wc -l)
      echo -e "  ${GREEN}级别${INIT_LEVEL} (${count}个服务)${NC}"
      local item
      for item in $services; do
        local service_name="${item/S[0-9][0-9]/}"
        echo -e "    ${item} -> ${service_name}"
      done
    else
      echo -e "  ${YELLOW}级别${INIT_LEVEL} (无服务)${NC}"
    fi
  else
    echo -e "  ${RED}级别${INIT_LEVEL} (目录不存在)${NC}"
  fi

  echo ""
  container_running \
    && echo -e "容器状态: ${GREEN}运行中${NC}" \
    || echo -e "容器状态: ${RED}已停止${NC}"

  echo ""
  echo -e "${BLUE}运行时文件:${NC} $PROOT_RUN_DIR"
  if [ -d "$PROOT_RUN_DIR" ]; then
    ls -la "$PROOT_RUN_DIR" 2>/dev/null | tail -n +2 | head -20
  fi
}

# 进入容器 shell
enter_container_shell() {
  check_distro_installed || return 1
  log_info "进入 Proot ${DISTRO_NAME} 环境..."
  $PROOT_CMD login "$DISTRO_NAME" --user "$INIT_USER" $PROOT_LOGIN_OPTS
}

# 在容器中执行命令
exec_container_command() {
  local command="$*"
  if [ -z "$command" ]; then
    log_error "请提供要执行的命令"
    echo "  使用: exec_container_command <命令>"
    return 1
  fi
  check_distro_installed || return 1
  log_info "在 Proot 容器中执行: $command"
  proot_exec /bin/bash -c "$command"
}

# 强制清理所有 proot 容器进程
force_cleanup() {
  log_warn "强制清理所有 Proot ${DISTRO_NAME} 进程..."

  # 杀掉 init 会话进程 (带标记)
  pkill -KILL -f "PROOT_INIT_SESSION" 2>/dev/null || true
  # 杀掉所有 proot-distro login 进程 (应急, 会影响交互 shell)
  pkill -KILL -f "proot-distro login ${DISTRO_NAME}" 2>/dev/null || true

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
  stop_init
  sleep 2
  start_init
}

# 命令行接口
proot_manager_cli() {
  case "${1:-help}" in
    start | s)
      start_init
      ;;
    stop | st)
      stop_init
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
      # 单服务管理: proot_cli.sh svc <start|stop|status|restart> <服务名>
      # 直接调用容器内 /etc/init.d/<服务名> (对齐 sysv init, 与 chroot 一致)
      local action="${2:-status}"
      local svc_name="${3:-}"
      if [ -z "$svc_name" ]; then
        echo "用法: $0 svc <start|stop|status|restart> <服务名>"
        echo "  服务名对应 /etc/init.d/<服务名> (如 noVNC, ssh, dbus)"
        return 1
      fi
      check_distro_installed || return 1
      if ! proot_exec test -x "/etc/init.d/$svc_name" 2>/dev/null; then
        log_error "未找到服务: $svc_name (/etc/init.d/$svc_name)"
        return 1
      fi
      proot_exec "/etc/init.d/$svc_name" "$action"
      ;;
    log)
      # 查看 init 服务日志
      local logfile="$PROOT_RUN_DIR/init.log"
      if [ -f "$logfile" ]; then
        tail -50 "$logfile"
      else
        log_warn "无日志: $logfile"
      fi
      ;;
    help | h | *)
      cat <<EOF
${BLUE}Proot-Distro ${DISTRO_NAME} 容器管理${NC} (对齐 chroot cli.sh 架构)

${GREEN}基础操作:${NC}
  ${YELLOW}start${NC}         启动 init 服务 (遍历 /etc/rc${INIT_LEVEL}.d/S*)
  ${YELLOW}stop${NC}          停止 init 服务 (rc6.d/K* + 杀常驻进程)
  ${YELLOW}restart${NC}       重启容器
  ${YELLOW}status${NC}        查看容器状态 + rc${INIT_LEVEL}.d 服务清单
  ${YELLOW}log${NC}           查看 init 服务日志

${GREEN}交互操作:${NC}
  ${YELLOW}shell${NC}/${YELLOW}enter${NC}    进入容器 shell
  ${YELLOW}exec${NC} <cmd>    在容器中执行命令

${GREEN}服务管理:${NC}
  ${YELLOW}svc${NC} <action> <name>  单服务管理 (直接调用 /etc/init.d/<name>)
                  action: start|stop|status|restart
                  name:    noVNC, ssh, dbus ... (由容器 init.d 决定)

${GREEN}安装/清理:${NC}
  ${YELLOW}install${NC}      安装 ${DISTRO_NAME} distro
  ${YELLOW}force-cleanup${NC} 强制清理所有 proot 进程

${GREEN}常用示例:${NC}
  proot_cli.sh start
  proot_cli.sh shell
  proot_cli.sh exec "apt update"
  proot_cli.sh svc start noVNC
  proot_cli.sh status

${GREEN}架构说明:${NC}
  服务清单由容器内 /etc/rc${INIT_LEVEL}.d/S* 决定
  (init_d_noVNC.sh + apt 包 postinst 生成, 与 chroot 版 cli.sh 共用同一套 init.d 配置)
  不再硬编码服务列表, 不依赖 proot-services.sh 中间层

${GREEN}环境变量:${NC}
  ${YELLOW}DISTRO_NAME${NC}=${DISTRO_NAME}   ${YELLOW}INIT_LEVEL${NC}=${INIT_LEVEL}
  ${YELLOW}INIT_USER${NC}=${INIT_USER}      ${YELLOW}INIT_ASYNC${NC}=${INIT_ASYNC}
EOF
      ;;
  esac
}

# 如果直接运行此脚本，则调用命令行接口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  proot_manager_cli "$@"
fi
