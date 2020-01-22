#!/bin/bash
sudo apt update
sudo apt-get upgrade 

echo "deb http://deb.debian.org/debian/ unstable main" | sudo tee --append /etc/apt/sources.list.d/unstable.list

printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' | sudo tee --append /etc/apt/preferences.d/limit-unstable
sudo apt-get update
sudo apt-get install wireguard -y
#wireguard需要内核模块,似乎在docker中也需要
