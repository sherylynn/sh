#!/bin/bash
#sudo apt update
lynn=/home/lynn

#常用工具
sudo apt install ssh tofrodos htop ncdu lrzsz vim -y

#xrdp
sudo apt install xrdp -y

#安装 xubuntu-desktop
sudo apt update
sudo apt install xubuntu-desktop language-selector-gnome update-manager chromium-browser -y

sudo echo xubuntu-session >~/.xsession
sudo service xrdp restart
#sudo systemctl isolate graphical.target

#start gui on boot
#sudo systemctl set-default graphical.target