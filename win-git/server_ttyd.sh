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

echo $(node -v)
echo $(go version)
echo $PATH
ttyd login -p 3000 -t fontSize=20
