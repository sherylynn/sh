#!/bin/bash
# source
. $(dirname "$0")/../win-git/toolsinit.sh
TOOLSRC_NAME=ibusrimerc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
#sudo pacman -Syu gvim android-tools fcitx5-rime fcitx5-configtool
sudo pacman -Syu gvim android-tools
#sudo pacman -S ibus-rime

#echo 'GTK_IM_MODULE=ibus QT_IM_MODULE=ibus XMODIFIERS=@im=ibus'> ${TOOLSRC}
sudo pacman -S fcitx5-im
tee ~/.xprofile <<-'EOF'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"

fcitx5 &
EOF
sudo pacman -S fcitx5-rime
