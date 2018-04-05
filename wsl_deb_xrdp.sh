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
sudo apt install xfce4 xfce4-terminal xterm language-pack-zh-hans language-selector-gnome update-manager chromium-browser -y

sudo sed -i 's/port=3389/port=3390/g' /etc/xrdp/xrdp.ini
sudo echo xfce4-session >~/.xsession
sudo service xrdp restart
#sudo systemctl isolate graphical.target

#start gui on boot
#sudo systemctl set-default graphical.target
sudo gnome-language-selector 
