#!/bin/bash
SCRIPT_NAME="pulseaudio"
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
${SCRIPT_NAME} --start --file /etc/pulse/default.pa
#pactl load-module module-simple-protocol-tcp rate=44100 format=s16le channels=2 source=auto_null.monitor record=true port=12345
#su $(whoami) -c 'ttyd -p 3000 -t fontSize=18 ssh localhost'
