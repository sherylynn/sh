#!/data/data/com.termux/files/usr/bin/bash
#------------------init function----------------
apt install getconf tsu
. $(dirname "$0")/../../win-get/toolsinit.sh
. ./cli.sh
. ./unchroot.sh

cd ~
if [[$(exist termux-setup-storage) == 1]];then
  termux-setup-storage
else
  mkdir -p ~/storage/downloads
fi
echo "在外部termux中彻底进行备份"

sudo tar -zpcvf ~/storage/downloads/backup_chroot_$(arch).tar.gz --exclude=~/storage --exclude=swap $DEBIAN_DIR
