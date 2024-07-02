#!/bin/bash
#------------------init function----------------
apt install getconf tsu -y
. $(dirname "$0")/../win-git/toolsinit.sh
cd ~
#sudo apt install pigz -y
#npm cache clean --force
termux-setup-storage

tar -zpcvf ~/storage/downloads/backup_termux_$(arch).tar.gz --exclude=.gvfs --exclude=.gnupg --exclude=.X* --exclude=.dbus --exclude=.config --exclude=storage --exclude=.x* --exclude=.vnc* --exclude=.cache --exclude=Seafile --exclude=swap ./
