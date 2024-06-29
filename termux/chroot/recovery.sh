#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
. ./cli.sh
#. ./unchroot.sh
. ./remove.sh
if [[$(exist termux-setup-storage) == 1]];then
  termux-setup-storage
else
  mkdir -p ~/storage/downloads
fi
cd /
pkg install pigz -y
sudo tar -I pigz -xvf ~/storage/downloads/backup_chroot_$(arch).tar.gz
