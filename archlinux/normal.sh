#!/bin/bash
# source
. $(dirname "$0")/../win-git/toolsinit.sh
TOOLSRC_NAME=ibusrimerc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
#sudo pacman -Syu gvim android-tools fcitx5-rime fcitx5-configtool
sudo pacman -Syu gvim android-tools
sudo pacman -S ibus-rime

echo 'GTK_IM_MODULE=ibus QT_IM_MODULE=ibus XMODIFIERS=@im=ibus'> ${TOOLSRC}
