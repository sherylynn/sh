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
test -f ../../tools/rc/noderc && . ../../tools/rc/noderc
test -f ../../tools/rc/golangrc && . ../../tools/rc/golangrc

echo $(node -v)
echo $(go version)
echo $PATH
code-server