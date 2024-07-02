#!/bin/bash
#------------------init function----------------
apt install getconf tsu pigz -y
. $(dirname "$0")/../win-git/toolsinit.sh
. ./chroot/cli.sh
. ./chroot/unchroot.sh

cd ~
if [ ! -d "~/storage/downloads"]; then
  termux-setup-storage
fi

#排除chroot的文件夹，在termux的根目录中直接备份
tar --use-compress-program="pigz -9" -pcvf ~/storage/downloads/backup_termux_$(arch).tar.gz --exclude=~/storage --exclude=swap --exclude=$DEBIAN_DIR/dev --exclude=$DEBIAN_DIR/proc --exclude=$DEBIAN_DIR/sys --exclude=$DEBIAN_DIR/sdcard --exclude=$DEBIAN_DIR/tmp --exclude=$DEBIAN_DIR --exclude=$TERMUX_DIR/lib --exclude=$TERMUX_DIR/apps $TERMUX_DIR
