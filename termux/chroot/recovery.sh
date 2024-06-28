#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
. ./cli.sh
. ./unchroot.sh
cd ~
pkg install pigz -y
tar -I pigz -xvf ~/storage/downloads/backup_termux_$(arch).tar.gz
