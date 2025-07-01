#!/bin/bash
. $(dirname "$0")/toolsinit.sh
cd ~
sudo apt install pigz -y

BACKUP_DIR="$HOME/download"
if [ -d "/sdcard/Download" ]; then
    BACKUP_DIR="/sdcard/Download"
fi

tar -I pigz -xvf "$BACKUP_DIR"/backup_$(arch).tar.gz
