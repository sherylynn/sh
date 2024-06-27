#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
pkg update -y
pkg upgrade -y
pkg install zsh -y
zsh ~/sh/termux/vmos_android13.sh
zsh ~/sh/termux/init.sh
zsh ~/sh/termux/emacs.sh
zsh ~/sh/termux/myemacs.sh
zsh ~/sh/termux/emacs_native.sh 
zsh ~/sh/termux/ttyd.sh
zsh ~/sh/win-git/zlua_new.sh 
emacs
apt remove build-essential cmake -y
apt autoremove -y
apt clean
