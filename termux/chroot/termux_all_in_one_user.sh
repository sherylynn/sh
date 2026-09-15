#!/data/data/com.termux/files/usr/bin/bash

# Termux UID 专用阶段：这里只运行包管理、基础服务和 Termux:X11。
set -e

export HOME="/data/data/com.termux/files/home"
export PREFIX="/data/data/com.termux/files/usr"
export TMPDIR="$PREFIX/tmp"
export PATH="$PREFIX/bin:/system/bin:/system/xbin"
export TERM="${TERM:-xterm-256color}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 用户阶段不需要重新提权；这些调用只用于清理同 UID 的旧桌面进程。
sudo() {
  while [ "${1:-}" = "-n" ]; do shift; done
  [ "${1:-}" = "--" ] && shift
  command "$@"
}

export TERMUX_SPLIT_USER_PHASE=1
. "$SCRIPT_DIR/termux_all_in_one.sh"

case "${1:-start}" in
  start)
    start_base_services
    start_x11
    ;;
  stop)
    stop_user_services
    ;;
  *)
    echo "用法: $0 [start|stop]" >&2
    exit 2
    ;;
esac
