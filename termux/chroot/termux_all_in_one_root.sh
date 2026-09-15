#!/data/data/com.termux/files/usr/bin/bash

# GhostLock 临时 root 专用阶段：这里只处理挂载、chroot 和共享 tmp。
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 临时 root 本身已经具备权限，让 cli.sh 现有的 sudo 调用保持兼容。
sudo() {
  while [ "${1:-}" = "-n" ]; do shift; done
  [ "${1:-}" = "--" ] && shift
  command "$@"
}

. "$SCRIPT_DIR/termux_all_in_one.sh"

case "${1:-start}" in
  prepare)
    # 必须在 X11 启动前清理；容器已挂载时绝不能碰共享 tmp。
    if ! container_mounted; then
      clean_tmp
    fi
    ;;
  start)
    start_chroot
    # GhostLock 从 Termux 侧代码启动，确保容器使用同一版本的 noVNC 脚本。
    if [ -f "$HOME/sh/win-git/server_noVNC.sh" ]; then
      cp "$HOME/sh/win-git/server_noVNC.sh" \
        "$CHROOT_DIR/root/sh/win-git/server_noVNC.sh"
      chmod 755 "$CHROOT_DIR/root/sh/win-git/server_noVNC.sh"
    fi
    # rc3 已经负责启动桌面和 noVNC。这里只等待服务就绪，绝不再次调用
    # noVNC init 脚本，否则会与 rc3 的异步启动竞态并产生两套 XFCE 会话。
    # 冷启动时 websockify 可能晚于 x11vnc，因此最多等待 30 秒。
    for _ in {1..60}; do
      if pgrep -x x11vnc >/dev/null 2>&1 &&
        pgrep -f 'newhome_websockify.py' >/dev/null 2>&1 &&
        grep -qE ':170C .* 0A ' /proc/net/tcp 2>/dev/null &&
        grep -qE ':2766 .* 0A ' /proc/net/tcp 2>/dev/null; then
        echo "[+] noVNC 健康检查通过: x11vnc=:5900 websockify=:10086"
        exit 0
      fi
      sleep 0.5
    done
    echo "[!] noVNC 健康检查失败，回传启动日志" >&2
    tail -120 "$CHROOT_DIR/root/.vnc/server-noVNC-startup.log" 2>/dev/null || true
    echo "[!] x11vnc 日志:" >&2
    tail -80 "$CHROOT_DIR/root/.vnc/x11vnc.log" 2>/dev/null || true
    exit 1
    ;;
  stop)
    stop_chroot_container 2>/dev/null || true
    clean_tmp
    ;;
  *)
    echo "用法: $0 [prepare|start|stop]" >&2
    exit 2
    ;;
esac
