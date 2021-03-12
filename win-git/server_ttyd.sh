#!/bin/bash
realpath(){
  local x=$1
  echo $(cd $(dirname $0);pwd)/$x

}
realpathdir(){
  local x=$1
  echo $(cd $(dirname $0);pwd)

}
cd $(realpathdir ./server_code-server.sh)
pwd
#load env
test -f ../../tools/rc/ttydrc && . ../../tools/rc/ttydrc

echo $(whoami)
# login need systemd user root
#ttyd -p 3000 -t fontSize=18 login
# login need systemd user $(whoami)
ttyd -p 3000 -t fontSize=18 ssh localhost
#su $(whoami) -c 'ttyd -p 3000 -t fontSize=18 ssh localhost'
