#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh

sudo cp ~/sh/debian/sources.list.huawei /etc/apt/sources.list
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 425956BB3E31DF51
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B8F213033DB6B2D6

sudo apt update
sudo apt remove fonts-dejavu-mono -y
sudo apt install fonts-dejavu-core -y
#sudo apt upgrade -y
#sudo apt dist-upgrade -y
sudo apt autoremove -y
