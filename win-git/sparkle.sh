#!/bin/bash
set -e 
sudo chmod 777 /sparkle
sudo chmod 777 /sparkle/wayland-0
XDG_RUNTIME_DIR=/sparkle Xwayland &
sleep 1
export DISPLAY=:0
xfce4-session
