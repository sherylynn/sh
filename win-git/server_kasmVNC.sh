#!/bin/bash
SCRIPT_NAME="kasmVNC"
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

cd ../../
vncserver -kill :0
vncserver -kill :1
killall Xvnc
rm -rf /tmp/.X*
rm -rf /tmp/.x*
#vncserver -hw3d -drinode /dev/dri/renderD128 -geometry 1920x966 :0
#vncserver -geometry 1920x966 :0
vncserver -select-de xfce
