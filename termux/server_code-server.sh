#!/data/data/com.termux/files/usr/bin/bash
#change bash from /usr/bin/bash to realpath
SCRIPT_NAME="code-server"
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
test -f ../../tools/rc/noderc && . ../../tools/rc/noderc
test -f ../../tools/rc/cclsrc && . ../../tools/rc/cclsrc
test -f ../../tools/rc/golangrc && . ../../tools/rc/golangrc
test -f ../../tools/rc/pythonrc && . ../../tools/rc/pythonrc

echo $(node -v)
echo $(go version)
echo $PATH
#use node to run code-server script to instead of /usr/bin/env lack of in termux without prefix
#node $(which code-server)
#不再使用npm方法安装的code-server，使用直接的code-server
${SCRIPT_NAME}
