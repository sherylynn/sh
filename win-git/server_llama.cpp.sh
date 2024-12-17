#!/bin/bash
SCRIPT_NAME="llama.cpp"
#change bash from /usr/bin/bash to realpath
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
test -f ../../tools/rc/${SCRIPT_NAME}rc && . ../../tools/rc/${SCRIPT_NAME}rc

echo $(whoami)
# login need systemd user root
#ttyd -p 3000 -t fontSize=18 login
# login need systemd user $(whoami)

#cd ../../tools/noVNC
cd ../../
#su $(whoami) -c 'ttyd -p 3000 -t fontSize=18 ssh localhost'
#llama-server -m /sdcard/Download/Qwen2.5.1-Coder-7B-Instruct-Q4_0_4_8.gguf --host 0.0.0.0 --port 8888
llama-server -m /sdcard/Download/Qwen2.5-7B-Instruct-Q4_0.gguf --host 0.0.0.0 --port 8888
