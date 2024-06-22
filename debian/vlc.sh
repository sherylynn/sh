#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh

sudo apt install vlc -y
sudo sed -i 's/geteuid/getppid/' /usr/bin/vlc
