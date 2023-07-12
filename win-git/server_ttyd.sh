#!/bin/bash
SCRIPT_NAME="ttyd"
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
${SCRIPT_NAME} -6 -p 3000 -t fontSize=18 ssh 127.0.0.1
#↑这个命令有一个缺点，不能开启本机的免密码(密钥)方式登录，不然会直接ssh进去，而login也有login的问题
#官方配置中login再加上-f可以指定用户
#su $(whoami) -c 'ttyd -p 3000 -t fontSize=18 ssh localhost'
