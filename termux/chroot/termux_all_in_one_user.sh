#!/data/data/com.termux/files/usr/bin/bash

# Termux UID 专用阶段：只运行 Termux 基础服务；显示由 NewHome Android compositor 持有。
set -e

export HOME="/data/data/com.termux/files/home"
export PREFIX="/data/data/com.termux/files/usr"
export TMPDIR="$PREFIX/tmp"
export PATH="$PREFIX/bin:/system/bin:/system/xbin"
export TERM="${TERM:-xterm-256color}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 用户阶段不需要重新提权；这里只管理同 UID 的基础服务。
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
    ;;
  stop)
    stop_user_services
    ;;
  *)
    echo "用法: $0 [start|stop]" >&2
    exit 2
    ;;
esac
