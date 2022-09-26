#!/bin/bash
realpath(){
  local x=$1
  echo $(cd $(dirname $0);pwd)/$x

}
cd $(realpath ./golang)
pwd
#load env
test -f ../../tools/rc/noderc && . ../../tools/rc/noderc
echo $(node -v)
./golang

#x11vnc -forever -display :0 -usepw
VNC_DISPLAY=0
export MESA_LOADER_DRIVER_OVERRIDE=zink
export GALLIUM_DRIVER=zink
rm "/tmp/.X${VNC_DISPLAY}-lock" "/tmp/.X11-unix/X${VNC_DISPLAY}"
#vncserver :${VNC_DISPLAY} -depth 16 -dpi 100 -geometry 1080x2295
#vncserver :${VNC_DISPLAY} -depth 16 -dpi 100 -geometry 1600x900
tightvncserver :${VNC_DISPLAY} -depth 16 -dpi 100 -geometry 1366x768
#tigervncserver :${VNC_DISPLAY} -depth 16 -dpi 100 -geometry 1600x900
