#!/bin/bash
#------------------init function----------------
apt install getconf tsu pigz
. $(dirname "$0")/../win-git/toolsinit.sh
cd ~
#sudo apt install pigz -y
#npm cache clean --force
if [[$(exist termux-setup-storage) == 1]];then
  termux-setup-storage
else
  mkdir -p ~/storage/downloads
fi
sudo tar -zpcvf ~/storage/downloads/backup_maruos_$(arch).tar.gz  /data/maru
