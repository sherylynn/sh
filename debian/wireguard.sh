#!/bin/bash
hostname="http://deb.debian.org/debian/"
mirror="http://mirrors.ustc.edu.cn/debian/"
read -p "should we use china mirror ? y or n : " RESTART
case $RESTART in
  y) hostname=$mirror ;;
  n) echo "enjoying" ;;
esac

echo $hostname

sudo apt update
sudo apt-get upgrade 

echo "deb $hostname unstable main" | sudo tee --append /etc/apt/sources.list.d/unstable.list

printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' | sudo tee --append /etc/apt/preferences.d/limit-unstable
sudo apt-get update
sudo apt-get install wireguard resolvconf -y
echo "记得修改配置中的网卡名"
#wireguard需要内核模块,似乎在docker中也需要
