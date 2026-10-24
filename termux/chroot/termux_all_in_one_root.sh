#!/data/data/com.termux/files/usr/bin/bash

# GhostLock 临时 root 专用阶段：挂载 chroot 并拉起 NewHome native Wayland/XFCE/noVNC。
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
    # 容器未挂载时才清理共享 tmp；已挂载环境绝不破坏运行时。
    if ! container_mounted; then
      clean_tmp
    fi
    ;;
  start)
    start_rooted_newhome_desktop
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
