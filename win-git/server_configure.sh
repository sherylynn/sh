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

#. ~/sh/win-git/toolsinit.sh
zsh ~/sh/debian/testing_mirror.sh

sudo apt install sudo zsh -y
sudo apt install dbus-x11 xfce4 xfce4-terminal tigervnc-standalone-server tigervnc-tools openssh-server -y
sudo chsh -s /bin/zsh
source ~/sh/win-git/toolsinit.sh
proxy
zsh ~/sh/raspberry/chinese.sh 
zsh ~/sh/debian/emacs.sh
zsh ~/sh/win-git/move2zsh.sh
zsh ~/sh/win-git/zlua_new.sh
zsh ~/sh/win-git/init_d_noVNC.sh 
zsh ~/sh/win-git/noVNC.sh 
zsh ~/sh/debian/wps.sh 
zsh ~/sh/debian/firefox.sh
#zsh ~/sh/debian/firefox.sh 
zsh ~/sh/myemacs.sh
emacs -nw
