#!/bin/bash
sudo apt update
sudo apt-get upgrade 

sudo apt install raspberrypi-kernel-headers

echo "deb http://deb.debian.org/debian/ unstable main" | sudo tee --append /etc/apt/sources.list.d/unstable.list

sudo apt-get install dirmngr 
sudo apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 8B48AD6246925553 
printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' | sudo tee --append /etc/apt/preferences.d/limit-unstable
sudo apt-get update
sudo apt-get install wireguard -y
#wireguard需要内核模块,似乎在docker中也需要