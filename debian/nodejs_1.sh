#!/bin/bash
#sudo apt update
lynn=$HOME
INSTALL_PATH=$HOME/tools
NODE_VERSION=8.12.0
#MIRROR=http://nodejs.org/dist
MIRROR=http://npm.taobao.org/mirrors/node
#arm64 x64
#NODE_ARCH=armv7l
NODE_ARCH=x64
#NODE_ARCH=arm64
#NODE_ARCH=x86
#常用工具

while getopts 'v:a:' OPT; do
  case $OPT in
    v)
      NODE_VERSION="$OPTARG";;
    a)
      NODE_ARCH="$OPTARG";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

shift $(($OPTIND - 1))

sudo apt update
sudo apt install ssh tofrodos htop ncdu lrzsz vim -y

#base debian 9 has python3-software-properties instead of python-software-properties
sudo apt install software-properties-common -y
sudo apt install axel wget curl git build-essential -y
sudo apt install python-software-properties -y
sudo apt install python -y
#--------------------------------------
#安装 nodejs
#--------------------------------------
if [ ! -d "${INSTALL_PATH}" ]; then
  mkdir $INSTALL_PATH
fi

#wget -q http://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz && \
#axel -n 10 http://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz && \
axel -n 10 ${MIRROR}/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz && \
    tar -xzf node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz && \
    rm -rf $INSTALL_PATH/node && \
sudo mv node-v${NODE_VERSION}-linux-${NODE_ARCH} $INSTALL_PATH/node && \
    rm node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz*
echo 'export PATH=$PATH:'${INSTALL_PATH}'/node/bin'>>~/.bashrc
source ~/.bashrc

#curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -
#sudo apt install nodejs -y

#----------------------------
# Set Global packages path
#----------------------------
if [ ! -d "$INSTALL_PATH/node-global" ]; then
  mkdir $INSTALL_PATH/node-global
fi
if [ ! -d "$INSTALL_PATH/node-cache" ]; then
  mkdir $INSTALL_PATH/node-cache
fi
if [ ! -d "$INSTALL_PATH/yarn-cache" ]; then
  mkdir $INSTALL_PATH/yarn-cache
fi
echo 'export PATH='$INSTALL_PATH'/node-global/bin:$PATH' >> ~/.bashrc
echo 'NPM_CONFIG_PREFIX='$INSTALL_PATH'/node-global' >> ~/.bashrc
echo 'NPM_CONFIG_CACHE='$INSTALL_PATH'/node-cache' >> ~/.bashrc
echo 'YARN_CACHE_FOLDER='$INSTALL_PATH'/yarn-cache' >> ~/.bashrc
source ~/.bashrc
