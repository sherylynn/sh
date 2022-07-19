#!/bin/bash
set -e 
sudo chmod 777 /sparkle
sudo chmod 777 /sparkle/wayland-0
XDG_RUNTIME_DIR=/sparkle Xwayland &
sleep 1
# if linux deploy has vnc so let it be :1
# if not set display number :0
export DISPLAY=:0
#export XDG_RUNTIME_DIR="/tmp/swaywm"
export XDG_RUNTIME_DIR="/tmp/weston"
mkdir -p $XDG_RUNTIME_DIR
chmod 0700 $XDG_RUNTIME_DIR
VNC_DISPLAY=0
rm "/tmp/.X${VNC_DISPLAY}-lock" "/tmp/.X11-unix/X${VNC_DISPLAY}"
weston --xwayland -B rdp-backend.so --rdp4-key ~/rdpkey/rdp-security.key
##weston -B drm-backend.so
##weston -B wayland-backend.so --display=:0
#sway
#weston -B x11-backend.so --height 2295 --width 1080
#xfce4-session
#XDG_RUNTIME_DIR=/sparkle sway
