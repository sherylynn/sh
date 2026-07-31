#!/bin/bash
# Proot 容器内部服务启动脚本
# 安装位置: /usr/local/bin/proot-services.sh
# 由 server_configure.sh 在 proot 模式下安装
# 由外部 proot_cli.sh 调用: proot-distro login debian -- /usr/local/bin/proot-services.sh start
#
# 与 chroot 版本的区别:
#   - 不依赖 sysv init (/etc/rc3.d/S*)
#   - 不依赖 /etc/init.d/ 系统
#   - 直接启动/停止各服务进程

set -e

# 环境变量
export DISPLAY="${DISPLAY:-:1}"
export PULSE_SERVER="${PULSE_SERVER:-127.0.0.1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"

# 运行时 PID 目录
RUN_DIR="/run/proot-services"
mkdir -p "$RUN_DIR" 2>/dev/null

# 日志
log() { echo "[$(date '+%H:%M:%S')] $1"; }

# === 单个服务管理 ===

# SSH 服务
start_sshd() {
  if pgrep -x sshd >/dev/null 2>&1; then
    log "sshd 已在运行"
    return 0
  fi
  # 生成 host key (首次启动)
  ssh-keygen -A 2>/dev/null || true
  # 启动 sshd
  /usr/sbin/sshd
  log "sshd 已启动 (pid=$(cat /run/sshd.pid 2>/dev/null || pgrep -x sshd | head -1))"
}

stop_sshd() {
  pkill -x sshd 2>/dev/null || true
  log "sshd 已停止"
}

# DBus 系统总线
start_dbus() {
  if pgrep -x dbus-daemon >/dev/null 2>&1; then
    log "dbus 已在运行"
    return 0
  fi
  # 生成 machine-id (若缺失)
  if [ ! -f /etc/machine-id ] || [ ! -s /etc/machine-id ]; then
    dbus-uuidgen 2>/dev/null > /etc/machine-id || \
      cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id
    chmod 644 /etc/machine-id
  fi
  mkdir -p /run/dbus /var/run/dbus
  dbus-daemon --system --fork
  log "dbus 已启动"
}

stop_dbus() {
  pkill -x dbus-daemon 2>/dev/null || true
  log "dbus 已停止"
}

# VNC 服务器 (tigervnc)
start_vnc() {
  if pgrep -x Xvnc >/dev/null 2>&1; then
    log "vnc 已在运行"
    return 0
  fi
  if ! command -v vncserver >/dev/null 2>&1; then
    log "vnc 未安装, 跳过"
    return 0
  fi
  # 首次需要 vncpasswd
  if [ ! -f ~/.vnc/passwd ]; then
    mkdir -p ~/.vnc
    # 设置默认密码 (可后续修改), 这里跳过让用户手动设置
    log "首次运行 VNC, 请稍后手动执行: vncpasswd"
    return 0
  fi
  vncserver :1 -geometry 1920x1080 -depth 24 2>&1 | tail -5
  log "vnc 已启动 (:1)"
}

stop_vnc() {
  vncserver -kill :1 2>/dev/null || pkill -x Xvnc 2>/dev/null || true
  log "vnc 已停止"
}

# noVNC web 客户端
start_novnc() {
  if pgrep -f "novnc_proxy" >/dev/null 2>&1; then
    log "novnc 已在运行"
    return 0
  fi
  local novnc_script=""
  for p in /usr/local/noVNC/utils/novnc_proxy /opt/noVNC/utils/novnc_proxy; do
    [ -x "$p" ] && novnc_script="$p" && break
  done
  if [ -z "$novnc_script" ]; then
    log "novnc 未安装, 跳过"
    return 0
  fi
  nohup "$novnc_script" --vnc 127.0.0.1:5901 --listen 10086 >/tmp/novnc.log 2>&1 &
  log "novnc 已启动 (http://localhost:10086/vnc.html)"
}

stop_novnc() {
  pkill -f "novnc_proxy" 2>/dev/null || true
  log "novnc 已停止"
}

# === 主入口 ===

ALL_SERVICES=(sshd dbus vnc novnc)

case "${1:-start}" in
  start)
    log "启动 Proot 容器服务..."
    for svc in "${ALL_SERVICES[@]}"; do
      "start_${svc}" 2>&1 || true
    done
    log "服务启动完成"
    ;;
  stop)
    log "停止 Proot 容器服务..."
    # 逆序停止
    for ((i=${#ALL_SERVICES[@]}-1; i>=0; i--)); do
      "stop_${ALL_SERVICES[i]}" 2>&1 || true
    done
    log "服务停止完成"
    ;;
  restart)
    "$0" stop
    sleep 1
    "$0" start
    ;;
  status)
    for svc in "${ALL_SERVICES[@]}"; do
      if pgrep -x "$svc" >/dev/null 2>&1 || pgrep -f "$svc" >/dev/null 2>&1; then
        echo "  ● $svc (运行中)"
      else
        echo "  ○ $svc (已停止)"
      fi
    done
    ;;
  *)
    echo "用法: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
