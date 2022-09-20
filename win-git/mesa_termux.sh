#!/bin/bash
set -e 
export XDG_RUNTIME_DIR="/root/termux_x11_tmp"
mkdir -p $XDG_RUNTIME_DIR
sudo chmod 600 /root/termux_x11_tmp
sudo chown root /root/termux_x11_tmp
sudo chgrp root /root/termux_x11_tmp
sudo chmod 777 /root/termux_x11_tmp/wayland-0
sudo chown root /root/termux_x11_tmp/wayland-0
sudo chgrp root /root/termux_x11_tmp/wayland-0
#chmod 0700 $XDG_RUNTIME_DIR
XDG_RUNTIME_DIR='/root/termux_x11_tmp' Xwayland &
sleep 1
# if linux deploy has vnc so let it be :1
# if not set display number :0
export DISPLAY=:0
#export XDG_RUNTIME_DIR="/tmp/swaywm"
VNC_DISPLAY=0
rm -rf "/tmp/.X${VNC_DISPLAY}-lock" "/tmp/.X11-unix/X${VNC_DISPLAY}"
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink
#weston --xwayland -B rdp-backend.so --rdp4-key ~/rdpkey/rdp-security.key
##weston -B drm-backend.so
##weston -B wayland-backend.so --display=:0
#sway
#weston -B x11-backend.so --height 2295 --width 1080
xfce4-session
#XDG_RUNTIME_DIR=/sparkle sway
