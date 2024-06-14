#!/data/data/com.termux/files/usr/bin/bash
SCRIPT_NAME="noVNC"
#change bash from /usr/bin/bash to realpath
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
#ttyd -p 3000 -t fontSize=18 login
# login need systemd user $(whoami)

#cd ../../tools/noVNC
cd ../../
vncserver -kill :1
vncserver -kill :2
vncserver -kill :3
rm -rf /data/data/com.termux/files/usr/tmp/.X*
rm -rf /data/data/com.termux/files/usr/tmp/.x*
#vncserver :1
vncserver -geometry 1920x966 :3

./tools/noVNC/utils/novnc_proxy --vnc 127.0.0.1:5903 --listen 10086
#su $(whoami) -c 'ttyd -p 3000 -t fontSize=18 ssh localhost'
