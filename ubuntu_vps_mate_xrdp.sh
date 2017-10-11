#!/bin/bash
#sudo apt update
lynn=/home/lynn

#常用工具
sudo apt install ssh tofrodos htop ncdu lrzsz vim -y

#xrdp
sudo apt install xrdp -y

#安装 mate
sudo apt-get update
sudo apt-get install mate-core mate-desktop-environment ubuntu-mate-themes mate-notification-daemon update-manager language-selector-gnome chromium-browser -y

sudo sed -i.bak '/fi/a #xrdp multiple users configuration \n mate-session \n' /etc/xrdp/startwm.sh

#sudo systemctl isolate graphical.target

#start gui on boot
#sudo systemctl set-default graphical.target

#在桌面环境下可以这样但是实际上在终端环境下应该是 sudo dist-upgrade
#sudo update-manager -d 
#sudo dpkg --configure -a