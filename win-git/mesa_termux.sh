#!/bin/bash
set -e 
export XDG_RUNTIME_DIR="/tmp"
#mkdir -p $XDG_RUNTIME_DIR
sudo chmod 777 /tmp
#sudo chown root /tmp
#sudo chgrp root /tmp
sudo chmod 777 /tmp/wayland-0
#sudo chown root /tmp/wayland-0
#sudo chgrp root /tmp/wayland-0
#chmod 0700 $XDG_RUNTIME_DIR
XDG_RUNTIME_DIR='/tmp' Xwayland &
sleep 1
export DISPLAY=:0
VNC_DISPLAY=0
rm -rf "/tmp/.X${VNC_DISPLAY}-lock" "/tmp/.X11-unix/X${VNC_DISPLAY}"
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink
xfce4-session & 
#dbus-launch --exit-with-session startxfce4
