#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
pkg update -y
pkg upgrade -y
sh ~/sh/termux/init.sh
sh ~/sh/myemacs.sh
sh ~/sh/termux/emacs.sh
sh ~/sh/termux/emacs_native.sh 
sh ~/sh/termux/ttyd.sh
sh ~/sh/win-git/zlua_new.sh 
