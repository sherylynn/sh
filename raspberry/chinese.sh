#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
NAME=chinese
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
#fuck raspbian and rime
#sudo rm -rf ~/.config/fcitx
#sudo apt install ibus-rime
#sudo apt install fcitx-rime
sudo apt install fcitx5 fcitx5-rime fonts-wqy-zenhei ttf-wqy-zenhei -y
#sudo apt install fcitx-googlepinyin -y
sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
sudo apt install locales -y
sudo locale-gen zh.CN.UTF-8
sudo dpkg-reconfigure locales

tee ${TOOLSRC} <<-'EOF'
export LANG=zh_CN.UTF-8
export LC_CTYPE="zh_CN.UTF-8"
export LC_NUMERIC="zh_CN.UTF-8"
export LC_TIME="zh_CN.UTF-8"
export LC_COLLATE="zh_CN.UTF-8"
export LC_MONETARY="zh_CN.UTF-8"
export LC_MESSAGES="zh_CN.UTF-8"
export LC_PAPER="zh_CN.UTF-8"
export LC_NAME="zh_CN.UTF-8"
export LC_ADDRESS="zh_CN.UTF-8"
export LC_TELEPHONE="zh_CN.UTF-8"
export LC_MEASUREMENT="zh_CN.UTF-8"
export LC_IDENTIFICATION="zh_CN.UTF-8"
export LC_ALL=
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
export GLFW_IM_MODULE=ibus
EOF

fcitx5_path=$(
  cd "$(dirname "$0")"
  pwd
)/../linuxdeploy/fcitx.sh
tee ~/.config/autostart/fcitx5.desktop <<EOF
 [Desktop Entry]
Type=Application
Name=FCITX5 Input Method
Exec=$fcitx5_path
Comment=Auto-start fcitx5 in chroot
EOF
