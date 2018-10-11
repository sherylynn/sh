#!/bin/bash
#add armhf
sudo dpkg --add-architecture armhf && sudo apt update
sudo apt install code-oss:armhf -y
sudo apt install -f -y