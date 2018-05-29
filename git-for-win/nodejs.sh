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
  unzip -q ${NODE_FILE_PACK}
fi
  rm -rf $INSTALL_PATH/node && \
  mv ${NODE_FILE_NAME} $INSTALL_PATH/node && \
  rm -rf ${NODE_FILE_PACK}

#----------------------------
# Set Global packages path
#----------------------------
if [ ! -d "$INSTALL_PATH/node-global" ]; then
  mkdir $INSTALL_PATH/node-global
fi
if [ ! -d "$INSTALL_PATH/node-cache" ]; then
  mkdir $INSTALL_PATH/node-cache
fi
#--------------new .toolsrc-----------------------
echo 'test -f ~/.toolsrc && . ~/.toolsrc' >> ~/.bash_profile
#windows下和linux下的不同
if [ ${OS}=='win' ]; then
  echo 'export PATH=$PATH:'${INSTALL_PATH}'/node'>~/.toolsrc
elif [ ${OS}=='linux' ]; then
  echo 'export PATH=$PATH:'${INSTALL_PATH}'/node/bin'>~/.toolsrc
fi
echo 'export PATH='$INSTALL_PATH'/node-global/bin:$PATH' >> ~/.toolsrc
echo 'NPM_CONFIG_PREFIX='$INSTALL_PATH'/node-global' >> ~/.toolsrc
echo 'NPM_CONFIG_CACHE='$INSTALL_PATH'/node-cache' >> ~/.toolsrc
source ~/.bashrc
#--------------new .npmrc ---------------------
#会安装到奇怪的地方
#echo 'prefix='$INSTALL_PATH'/node-global' > ~/.npmrc
#echo 'cache='$INSTALL_PATH'/node-cache' >> ~/.npmrc
