#!/bin/bash
BREW_COMMAND="v2raya"
SCRIPT_NAME="brew_${BREW_COMMAND}"
CONFIG_DIR="../../.config/v2raya"
realpath(){
  local x=$1
  echo $(cd $(dirname $0);pwd)/$x

}
realpathdir(){
  local x=$1
  echo $(cd $(dirname $0);pwd)

}
realconfigpath(){
  local x=$1
  echo $(cd $1;pwd)
}
cd $(realpathdir ./server_${SCRIPT_NAME}.sh)
pwd
#load env
test -f ../../tools/rc/noderc && . ../../tools/rc/noderc
test -f ../../tools/rc/cclsrc && . ../../tools/rc/cclsrc
test -f ../../tools/rc/golangrc && . ../../tools/rc/golangrc
test -f ../../tools/rc/pythonrc && . ../../tools/rc/pythonrc
test -f ../../tools/rc/brewrc && . ../../tools/rc/brewrc

test -f ../../tools/rc/${SCRIPT_NAME}rc && . ../../tools/rc/${SCRIPT_NAME}rc

echo $(node -v)
echo $(go version)
echo $PATH
echo $(realconfigpath ${CONFIG_DIR})
#${BREW_COMMAND} --v2ray-bin $(which xray) --config ./../../.config/v2raya  --lite
${BREW_COMMAND} --config $(realconfigpath ${CONFIG_DIR}) --lite
