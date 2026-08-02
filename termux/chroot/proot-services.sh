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
  # sshd 要求 privilege separation 目录 (否则报 "Missing privilege separation directory: /run/sshd")
  mkdir -p /run/sshd
  # 启动 sshd
  if /usr/sbin/sshd 2>/tmp/sshd.err; then
    log "sshd 已启动 (pid=$(cat /run/sshd.pid 2>/dev/null || pgrep -x sshd | head -1))"
  else
    log "sshd 启动失败: $(cat /tmp/sshd.err 2>/dev/null)"
  fi
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
  if dbus-daemon --system --fork 2>/tmp/dbus.err; then
    log "dbus 已启动"
  else
    log "dbus 启动失败: $(cat /tmp/dbus.err 2>/dev/null)"
    log "提示: 确认已安装 dbus 包 (apt install dbus)"
  fi
}

stop_dbus() {
  pkill -x dbus-daemon 2>/dev/null || true
  log "dbus 已停止"
}

# VNC 服务器 (x11vnc: 把 termux-x11 的 :1 转成 VNC, 供 noVNC 远程访问)
# 链路: termux-x11(:1) -> x11vnc(5901) -> noVNC(10086) -> 浏览器
# 注意: 用 x11vnc 连接已有 :1, 不用 vncserver (后者会新建 :1 与 termux-x11 冲突)
#   如需密码: 把 -nopw 换成 -rfbauth ~/.vnc/passwd (x11vnc 兼容 vncpasswd 格式)
start_vnc() {
  if pgrep -x x11vnc >/dev/null 2>&1; then
    log "x11vnc 已在运行"
    return 0
  fi
  if ! command -v x11vnc >/dev/null 2>&1; then
    log "x11vnc 未安装, 跳过"
    return 0
  fi
  # 等待 termux-x11 的 :1 就绪 (最多 ~10s), 共享 tmp 后 socket 在 /tmp/.X11-unix/X1
  for i in $(seq 1 20); do
    [ -S /tmp/.X11-unix/X1 ] && break
    sleep 0.5
  done
  if [ ! -S /tmp/.X11-unix/X1 ]; then
    log "警告: :1 的 X server 未就绪, x11vnc 可能启动失败"
  fi
  nohup x11vnc -display :1 -forever -shared -rfbport 5901 -nopw >/tmp/x11vnc.log 2>&1 &
  log "x11vnc 已启动 (VNC :5901, 连接 termux-x11 :1)"
}

stop_vnc() {
  pkill -x x11vnc 2>/dev/null || true
  log "x11vnc 已停止"
}

# noVNC web 客户端
start_novnc() {
  if pgrep -f "novnc_proxy" >/dev/null 2>&1; then
    log "novnc 已在运行"
    return 0
  fi
  local novnc_script=""
  # noVNC.sh 把 noVNC git clone 到 $(install_path)/noVNC, 即 ~/tools/noVNC
  for p in "$HOME/tools/noVNC/utils/novnc_proxy" /usr/local/noVNC/utils/novnc_proxy /opt/noVNC/utils/novnc_proxy; do
    [ -x "$p" ] && novnc_script="$p" && break
  done
  # 也尝试从 PATH 查找 (noVNC.sh 会把 noVNC 目录加入 PATH)
  if [ -z "$novnc_script" ]; then
    novnc_script=$(command -v novnc_proxy 2>/dev/null)
  fi
  if [ -z "$novnc_script" ]; then
    log "novnc 未安装, 跳过 (查找: ~/tools/noVNC, /usr/local/noVNC, PATH)"
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
      # 服务名与实际进程名映射 (vnc->x11vnc, novnc->novnc_proxy)
      local pat="$svc"
      [ "$svc" = "vnc" ] && pat="x11vnc"
      [ "$svc" = "novnc" ] && pat="novnc_proxy"
      if pgrep -x "$pat" >/dev/null 2>&1 || pgrep -f "$pat" >/dev/null 2>&1; then
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
