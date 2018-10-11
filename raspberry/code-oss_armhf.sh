#!/bin/bash
#add armhf
sudo bash <(curl -L -s https://code.headmelted.com/installers/apt.sh )
sudo dpkg --add-architecture armhf && sudo apt update
sudo apt install code-oss:armhf -y
sudo apt install -f -y
