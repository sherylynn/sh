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

cd ../../tools/noVNC

./utils/novnc_proxy --vnc 127.0.0.1:5901 --listen 10000
#su $(whoami) -c 'ttyd -p 3000 -t fontSize=18 ssh localhost'
