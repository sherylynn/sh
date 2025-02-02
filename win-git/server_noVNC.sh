#!/bin/bash
SCRIPT_NAME="noVNC"
realpath() {
  local x=$1
  echo $(
    cd $(dirname $0)
    pwd
  )/$x

}
realpathdir() {
  local x=$1
  echo $(
    cd $(dirname $0)
    pwd
  )

}
cd $(realpathdir ./server_${SCRIPT_NAME}.sh)
pwd
#load env
test -f ../../tools/rc/${SCRIPT_NAME}rc && . ../../tools/rc/${SCRIPT_NAME}rc

echo $(whoami)
# login need systemd user root
#novnc -p 3000 -t fontSize=18 login
# login need systemd user $(whoami)

#virgl
if pgrep -f "virgl_test" >/dev/null; then
  #export DISPLAY=:0
  export PULSE_SERVER=127.0.0.1
  export GTK_IM_MODULE="fcitx"
  export QT_IM_MODULE="fcitx"
  export XMODIFIERS="@im=fcitx"
  export GALLIUM_DRIVER=virpipe
  export MESA_GL_VERSION_OVERRIDE=4.0
fi

#x11
DISPLAY_PORT=0
cd ../../
if pgrep -f "com.termux.x11" >/dev/null; then
  DISPLAY_PORT=1
  export DISPLAY=:${DISPLAY_PORT}
  #当文件本身是bash启动的时候，这里用source就无效，但是本身是zsh启动的时候，再用zsh就无效
  #source  ~/tools/rc/allToolsrc
  zsh ~/tools/rc/allToolsrc
  dbus-launch --exit-with-session startxfce4
  #x11vnc -display :1 -rfbport 5900 -passwd yourpasswd -forever --noshm

else
  vncserver -kill :${DISPLAY_PORT}
  rm -rf /tmp/.X*
  rm -rf /tmp/.x*
  vncserver -geometry 1920x966 -localhost no :${DISPLAY_PORT}
  file_path="./tools/noVNC/utils/novnc_proxy"
  if [ -e "$file_path" ]; then
    ./tools/noVNC/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10086
    #./tools/noVNC/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10000
  else
    cd .
    #./tools/noVNC/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10000
    ./tools/noVNC/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10086
  fi
#./utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10086
#su $(whoami) -c 'novnc -p 3000 -t fontSize=18 ssh localhost'
fi
