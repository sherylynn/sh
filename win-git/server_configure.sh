#!/bin/bash
SCRIPT_NAME="configure"
realpath(){
  local x=$1
  echo $(cd $(dirname $0);pwd)/$x

}
realpathdir(){
  local x=$1
  echo $(cd $(dirname $0);pwd)

}
cd $(realpathdir ./server_${SCRIPT_NAME}.sh)
pwd
#load env
test -f ../../tools/rc/${SCRIPT_NAME}rc && . ../../tools/rc/${SCRIPT_NAME}rc

echo $(whoami)


sudo apt install git vim wget curl -y
git clone --depth 1 http://github.com/sherylynn/sh ~/sh
git -C ~/sh pull

termux_data_path=/data/data/com.termux/files/home
termux_gitcredentials=$termux_data_path/.git-credentials
termux_gitconfig=$termux_data_path/.gitconfig

test -f  $termux_gitconfig && sudo cp $termux_gitconfig ~/
test -f  $termux_gitcredentials && sudo cp $termux_gitcredentials ~/

#~/sh/debian/debian_mirror.sh
sudo cp ~/sh/debian/sources.list.tuna /etc/apt/sources.list
sudo apt update
sudo apt upgrade
sudo apt dist-upgrade
sudo apt autoremove -y
sudo apt install sudo zsh -y
sudo apt install dbus-x11 xfce4 xfce4-terminal chromium fcitx5 fcitx5-rime fonts-wqy-zenhei ttf-wqy-zenhei tigervnc-standalone-server tigervnc-tools openssh-server -y
sudo chsh -s /bin/zsh
source ~/sh/win-git/toolsinit.sh
proxy
zsh ~/sh/win-git/move2zsh.sh
zsh ~/sh/win-git/zlua_new.sh
zsh ~/sh/win-git/init_d_noVNC.sh 
zsh ~/sh/win-git/noVNC.sh 
