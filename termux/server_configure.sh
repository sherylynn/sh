#!/data/data/com.termux/files/usr/bin/bash
pkg update -y
pkg upgrade -y
pkg install zsh tsu -y
zsh ~/sh/termux/vmos_android13.sh
zsh ~/sh/termux/init.sh

if [ ! -d "~/storage/downloads"]; then
  termux-setup-storage
fi
cd ~
cp ~/storage/downloads/.gitconfig ~/
cp ~/storage/downloads/.git-credentials ~/
zsh ~/sh/lynn.sh work
. $(dirname "$0")/../win-git/toolsinit.sh
zsh ~/sh/win-git/move2zsh.sh
zsh ~/sh/win-git/zlua_new.sh
zsh ~/sh/termux/ttyd.sh
zsh ~/sh/termux/emacs.sh
zsh ~/sh/myemacs.sh
zsh ~/sh/termux/emacs_native.sh 
zsh ~/sh/win-git/zlua_new.sh 
emacs
zsh ~/sh/termux/clean.sh
