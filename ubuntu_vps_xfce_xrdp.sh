#!/bin/bash
#sudo apt update
lynn=/home/lynn

#常用工具
sudo apt install ssh tofrodos wget  htop ncdu lrzsz vim apt-transport-https mousepad -y

#xrdp
sudo apt install xrdp -y

#安装 xfce4 language-selector-gnome
#gsettings set org.gnome.desktop.input-sources  sources "[('xkb', 'us'),('xkb','es'),('xkb','zh')]"
sudo apt update
sudo apt install xfce4 xterm language-pack-zh-hans language-selector-gnome update-manager chromium-browser -y

sudo echo xfce4-session >~/.xsession
sudo service xrdp restart
#sudo systemctl isolate graphical.target

#start gui on boot
#sudo systemctl set-default graphical.target
sudo gnome-language-selector 
