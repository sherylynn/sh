#!/bin/bash
INSTALL_PATH=$HOME/tools
NODE_VERSION=8.11.2
NODE_ARCH=x64
OS=win
NODE_FILE_NAME=node-v${NODE_VERSION}-${OS}-${NODE_ARCH}
NODE_FILE_PACK=${NODE_FILE_NAME}.zip
cd ~
#--------------------------------------
#安装 nodejs
#--------------------------------------
if [ ! -d "${INSTALL_PATH}" ]; then
  mkdir $INSTALL_PATH
fi

if [ ! -f "${NODE_FILE_PACK}" ]; then
  curl -o ${NODE_FILE_PACK} http://cdn.npm.taobao.org/dist/node/v${NODE_VERSION}/${NODE_FILE_PACK} 
fi

if [ ! -d "${NODE_FILE_NAME}" ]; then
  unzip ${NODE_FILE_PACK}
fi
  rm -f $INSTALL_PATH/node && \
  mv ${NODE_FILE_NAME} $INSTALL_PATH/node && \
  rm ${NODE_FILE_PACK}
echo 'export PATH=$PATH:'${INSTALL_PATH}'/node/bin'>>~/.bashrc
source ~/.bashrc
