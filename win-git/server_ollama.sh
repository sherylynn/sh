#!/bin/bash
SCRIPT_NAME="ollama"
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
test -f ../../tools/rc/noderc && . ../../tools/rc/noderc
test -f ../../tools/rc/cclsrc && . ../../tools/rc/cclsrc
test -f ../../tools/rc/golangrc && . ../../tools/rc/golangrc
test -f ../../tools/rc/pythonrc && . ../../tools/rc/pythonrc

test -f ../../tools/rc/${SCRIPT_NAME}rc && . ../../tools/rc/${SCRIPT_NAME}rc

${SCRIPT_NAME} serve
