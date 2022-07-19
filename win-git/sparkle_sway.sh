#!/bin/bash
set -e 
sudo chmod 777 /sparkle
sudo chmod 777 /sparkle/wayland-0
XDG_RUNTIME_DIR=/sparkle Xwayland &
sleep 1
export DISPLAY=:0
export XDG_RUNTIME_DIR="/tmp/swaywm"
#export XDG_RUNTIME_DIR="/tmp/weston"
mkdir -p $XDG_RUNTIME_DIR
sudo chmod 0700 $XDG_RUNTIME_DIR
#weston -B rdp-backend.so --rdp4-key ~/rdpkey/rdp-security.key
##weston -B wayland-backend.so --display=:0
sway
#xfce4-session
#XDG_RUNTIME_DIR=/sparkle sway
