#!/bin/bash
#sudo apt update
lynn=/home/lynn

#install htop
sudo yum install epel-release -y

#常用工具
sudo yum install ssh curl htop net-tools ncdu dos2unix vim git lrzsz -y

#安装并启动x windows服务
sudo yum groupinstall "X Window system" -y

#安装 xfce
sudo yum groupinstall xfce -y

#sudo systemctl isolate graphical.target

#start gui on boot
#sudo systemctl set-default graphical.target

sudo yum -y install xrdp tigervnc-server chromium
#中文方框显示支持
sudo yum groupinstall "fonts"

#SELinux
sudo chcon -t bin_t /usr/sbin/xrdp
sudo chcon -t bin_t /usr/sbin/xrdp-sesman
#firewalld
sudo firewall-cmd --permanent --zone=public --add-port=3389/tcp
sudo firewall-cmd --reload

sudo systemctl start xrdp
sudo systemctl enable xrdp

sudo echo xfce4-session >~/.xsession
sudo echo 'startxfce4' > ~/.Xclients
sudo chmod +x ~/.Xclients
sudo systemctl restart xrdp
