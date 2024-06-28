#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
. ./cli.sh
. ./unchroot.sh
cd ~
pkg install pigz -y
sudo tar -I pigz -xvf ~/storage/downloads/backup_chroot_$(arch).tar.gz
