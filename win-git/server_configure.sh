#!/bin/bash
SCRIPT_NAME="configure"
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


sudo apt install git vim wget curl -y
git clone --depth 1 http://github.com/sherylynn/sh ~/sh
git -C ~/sh pull

~/sh/debian/debian_mirror.sh
sudo apt update
sudo apt upgrade
sudo apt autoremove -y
sudo apt install sudo zsh -y
