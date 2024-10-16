#!/bin/bash
SCRIPT_NAME="configure"
realpath() {
  local x=$1
  echo $(
    cd $(dirname $0)
    pwd
  )/$x

}
realpathdir() {
  local x=$1
  echo $(
    cd $(dirname $0)
    pwd
  )

}
cd $(realpathdir ./server_${SCRIPT_NAME}.sh)
pwd
#load env
test -f ../../tools/rc/${SCRIPT_NAME}rc && . ../../tools/rc/${SCRIPT_NAME}rc

echo $(whoami)

sudo apt install git vim wget curl sudo -y
git clone --depth 1 http://github.com/sherylynn/sh ~/sh
git -C ~/sh pull

#. ~/sh/win-git/toolsinit.sh
#zsh ~/sh/debian/testing_mirror.sh
#zsh ~/sh/debian/bullseyes_mirror.sh
#deepin
#sudo cp ~/sh/debian/sources.list.deepin /etc/apt/sources.list

sudo apt install zsh -y
sudo apt install dbus-x11 xfce4 openssh-server -y
sudo apt install tigervnc-standalone-server tigervnc-tools -y
sudo apt install xfce4-terminal -y
sudo apt install telegram-desktop ncdu htop -y
sudo chsh -s /bin/zsh
. $(dirname "$0")/../win-git/toolsinit.sh
source ~/sh/win-git/toolsinit.sh
proxy
zsh ~/sh/raspberry/chinese.sh
zsh ~/sh/lynn.sh work
zsh ~/sh/win-git/move2zsh.sh
zsh ~/sh/win-git/zlua_new.sh
zsh ~/sh/win-git/init_d_noVNC.sh
zsh ~/sh/win-git/noVNC.sh
zsh ~/sh/win-git/koreader.sh
if [ -d "/sdcard" ]; then
  sudo ln -s /sdcard/Download/BaiduNetdisk/_pcs_.workspace/ /root/Documents/百度云盘
fi
#zsh ~/sh/debian/wps.sh
zsh ~/sh/debian/firefox.sh
if [[ $(platform) == *wsl* ]]; then
  sh ~/sh/win-git/ssh.sh
fi
#确保toolsrc正确
#zsh ~/sh/debian/firefox.sh
#zsh ~/sh/debian/wps.sh
zsh ~/sh/debian/spark-store.sh
zsh ~/sh/debian/vlc.sh
zsh ~/sh/myemacs.sh
zsh ~/sh/debian/emacs.sh
zsh ~/sh/debian/R.sh
emacs -nw
