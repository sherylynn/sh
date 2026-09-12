#!/data/data/com.termux/files/usr/bin/bash
# 兼容旧入口。快捷命令现在由 toolsinit.sh 每次启动 shell 时直接从 Git 仓库
# 加载，不再生成需要手动刷新的 ~/tools/rc/termux_aliasesrc。
set -e

PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
HOME=${HOME:-/data/data/com.termux/files/home}
PROJECT_ROOT="$HOME/sh"

if [ "$PREFIX" != /data/data/com.termux/files/usr ] || \
   [ ! -x "$PREFIX/bin/pkg" ]; then
  echo "这些桌面快捷命令仅适用于 Termux，不会写入 chroot Linux。"
  exit 0
fi

. "$PROJECT_ROOT/win-git/toolsinit.sh"
echo "Termux 快捷命令已从当前 Git 仓库加载。"
echo "tstart=Termux:X11，pstart=proot，wstart/wstop/wrestart=Anland Wayland。"
