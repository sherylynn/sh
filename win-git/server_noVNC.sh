#!/bin/bash
SCRIPT_NAME="noVNC"
realpath(){
  local x=$1
  echo $(cd $(dirname $0);pwd)/$x

}
realpathdir(){
  local x=$1
  echo $(cd $(dirname $0);pwd)

}
cd $(realpathdir ./server_${SCRIPT_NAME}.sh)
pwd
#load env
test -f ../../tools/rc/${SCRIPT_NAME}rc && . ../../tools/rc/${SCRIPT_NAME}rc

echo $(whoami)
# login need systemd user root
#novnc -p 3000 -t fontSize=18 login
# login need systemd user $(whoami)
cd ../../tools/noVNC
rm -rf /tmp/.X*
rm -rf /tmp/.x*
vncserver -kill :0
vncserver -geometry 1920x966 :0
./utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10000
#./utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10086
#su $(whoami) -c 'novnc -p 3000 -t fontSize=18 ssh localhost'
