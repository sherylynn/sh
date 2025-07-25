#!/bin/bash
SCRIPT_NAME="configure"
#SOFT_VNC=kasmvnc
SOFT_VNC=tigervnc
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

sudo apt install git vim wget curl sudo jq -y
git clone --depth 1 http://github.com/sherylynn/sh ~/sh
git -C ~/sh pull

#. ~/sh/win-git/toolsinit.sh
#zsh ~/sh/debian/testing_mirror.sh
#zsh ~/sh/debian/bullseyes_mirror.sh
#deepin
#sudo cp ~/sh/debian/sources.list.deepin /etc/apt/sources.list
if [ -d "/sdcard" ]; then
  sdcard_rime=/sdcard/Download/rime
  sdcard_ssh=/sdcard/Download/.ssh
  sdcard_gitconfig=/sdcard/Download/.gitconfig
  sdcard_gitcredentials=/sdcard/Download/.git-credentials
  sudo rm -rf ~/.gitconfig
  test -f $sdcard_gitconfig && sudo ln -s $sdcard_gitconfig ~/.gitconfig
  sudo rm -rf ~/.git-credentials
  test -f $sdcard_gitcredentials && sudo ln -s $sdcard_gitcredentials ~/.git-credentials
  #复用输入法词库
  sudo rm -rf ~/rime
  test -d $sdcard_rime && sudo ln -s $sdcard_rime ~/rime
  sudo ln -s /sdcard/Download/BaiduNetdisk/_pcs_.workspace/ /root/Documents/百度云盘
fi

sudo apt install zsh -y
sudo apt install dbus-x11 xfce4 openssh-server -y
#换一种vnc
sudo apt install xfce4-terminal -y
sudo apt install telegram-desktop -y
sudo apt install ncdu htop android-platform-tools-base -y
sudo chsh -s /bin/zsh
. $(dirname "$0")/../win-git/toolsinit.sh
source ~/sh/win-git/toolsinit.sh
proxy
zsh ~/sh/raspberry/chinese.sh
zsh ~/sh/lynn.sh work
zsh ~/sh/win-git/move2zsh.sh
zsh ~/sh/win-git/zlua_new.sh
#换一种新式vnc来玩玩
if [[ $SOFT_VNC == *tigervnc* ]]; then
  zsh ~/sh/win-git/init_d_noVNC.sh
  zsh ~/sh/win-git/noVNC.sh
else
  zsh ~/sh/win-git/kasmVNC.sh
fi
zsh ~/sh/win-git/koreader.sh
zsh ~/sh/debian/firefox.sh
if [[ $(platform) == *wsl* ]]; then
  sh ~/sh/win-git/ssh.sh
fi
#确保toolsrc正确
#zsh ~/sh/debian/firefox.sh
zsh ~/sh/debian/wps.sh
#zsh ~/sh/debian/todesk.sh
#todesk无法联网
zsh ~/sh/debian/wechat.sh
zsh ~/sh/win-git/qq.sh
#zsh ~/sh/debian/spark-store.sh
zsh ~/sh/debian/vlc.sh
zsh ~/sh/win-git/scrcpy.sh
zsh ~/sh/myemacs.sh
zsh ~/sh/debian/emacs.sh
#zsh ~/sh/win-git/emacs.sh
zsh ~/sh/debian/R.sh
emacs -nw
