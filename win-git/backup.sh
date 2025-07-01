#!/bin/bash
#------------------init function----------------
. $(dirname "$0")/toolsinit.sh
cd ~
#sudo apt install pigz -y
#npm cache clean --force

BACKUP_DIR="$HOME/download"
if [ -d "/sdcard/Download" ]; then
    BACKUP_DIR="/sdcard/Download"
fi
mkdir -p "$BACKUP_DIR"

if [ -d "/sdcard/Download" ]; then
    tar --exclude=.gvfs --exclude=.gnupg --exclude=.X* --exclude=.dbus --exclude=.config/chromium --exclude=.config/gtk-3.0 --exclude=.config/pulse --exclude=.config/dconf --exclude=.config/htop  --exclude=.x* --exclude=.vnc* --exclude=.cache  -pcvf - ./  |pigz --best > "$BACKUP_DIR"/backup_$(arch).tar.gz
elif
    tar --exclude=.gvfs --exclude=.gnupg --exclude=.X* --exclude=.dbus --exclude=.config/chromium --exclude=.config/gtk-3.0 --exclude=.config/pulse --exclude=.config/dconf --exclude=.config/htop  --exclude=download --exclude=.x* --exclude=.vnc* --exclude=.cache  -pcvf - ./  |pigz --best > "$BACKUP_DIR"/backup_$(arch).tar.gz
fi
