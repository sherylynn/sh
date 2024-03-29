#!/bin/bash
#------------------init function----------------
. $(dirname "$0")/toolsinit.sh
cd ~
#sudo apt install pigz -y
#npm cache clean --force
mkdir -p ~/download
#tar -zpcvf ~/download/backup.tar.gz --exclude=download --exclude=.cache ./*
#tar -pcvf ~/download/backup.tar.gz --exclude=download --exclude=.cache -I pigz ./*

#tar --use-compress-program="pigz -9" -pcvf ~/download/backup.tar.gz --exclude=download --exclude=.cache  ./*
#./* 会没有隐藏文件
#tar --exclude=download --exclude=.cache  -pcvf - ./*  |pigz --best > ~/download/backup.tar.gz
#tar --exclude=.dbus --exclude=.config --exclude=download --exclude=.x* --exclude=.vnc* --exclude=.cache  -pcvf - ./  |pigz --best > ~/download/backup.tar.gz

tar --exclude=.gvfs --exclude=.gnupg --exclude=.X* --exclude=.dbus --exclude=.config/chromium --exclude=.config/gtk-3.0 --exclude=.config/pulse --exclude=.config/dconf --exclude=.config/htop  --exclude=download --exclude=.x* --exclude=.vnc* --exclude=.cache  -pcvf - ./  |pigz --best > ~/download/backup_$(arch).tar.gz
