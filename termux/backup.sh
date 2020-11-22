#!/bin/bash
#------------------init function----------------
apt install getconf tsu
. $(dirname "$0")/../win-git/toolsinit.sh
cd ~
#sudo apt install pigz -y
#npm cache clean --force
if [[$(exist termux-setup-storage) == 1]];then
  termux-setup-storage
else
  mkdir -p ~/storage/downloads
fi
#tar -zpcvf ~/download/backup.tar.gz --exclude=download --exclude=.cache ./*
#tar -pcvf ~/download/backup.tar.gz --exclude=download --exclude=.cache -I pigz ./*

#tar --use-compress-program="pigz -9" -pcvf ~/download/backup.tar.gz --exclude=download --exclude=.cache  ./*
#./* 会没有隐藏文件
#tar --exclude=download --exclude=.cache  -pcvf - ./*  |pigz --best > ~/download/backup.tar.gz
#tar --exclude=.dbus --exclude=.config --exclude=download --exclude=.x* --exclude=.vnc* --exclude=.cache  -pcvf - ./  |pigz --best > ~/download/backup.tar.gz

#tar -zpcvf ~/storage/downloads/backup_termux_$(arch).tar.gz --exclude=.gvfs --exclude=.gnupg --exclude=.X* --exclude=.dbus --exclude=.config --exclude=storage --exclude=.x* --exclude=.vnc* --exclude=.cache --exclude=.deepinwine ./
tar -zpcvf ~/storage/downloads/backup_termux_$(arch).tar.gz --exclude=.gvfs --exclude=.gnupg --exclude=.X* --exclude=.dbus --exclude=.config --exclude=storage --exclude=.x* --exclude=.vnc* --exclude=.cache ./
