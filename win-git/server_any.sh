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
