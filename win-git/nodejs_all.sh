# source
INSTALL_PATH=$HOME/tools
NODE_VERSION=10.15.0
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
  echo 'export PATH='$INSTALL_PATH'/node-global:$PATH' >> ~/.toolsrc
elif [ ${OS}=='linux' ]; then
  echo 'export PATH=$PATH:'${INSTALL_PATH}'/node/bin'>~/.toolsrc
  echo 'export PATH='$INSTALL_PATH'/node-global/bin:$PATH' >> ~/.toolsrc
fi
echo 'NPM_CONFIG_PREFIX='$INSTALL_PATH'/node-global' >> ~/.toolsrc
echo 'NPM_CONFIG_CACHE='$INSTALL_PATH'/node-cache' >> ~/.toolsrc
#-----env--------------------------------------------------
export PATH=$PATH:'${INSTALL_PATH}'/node/bin
export PATH='$INSTALL_PATH'/node-global/bin:$PATH
export NPM_CONFIG_PREFIX='$INSTALL_PATH'/node-global
export NPM_CONFIG_CACHE='$INSTALL_PATH'/node-cache
export YARN_CACHE_FOLDER='$INSTALL_PATH'/yarn-cache
export ELECTRON_MIRROR=http://npm.taobao.org/mirrors/electron/
export SQLITE3_BINARY_SITE=http://npm.taobao.org/mirrors/sqlite3
export PHANTOMJS_CDNURL=http://npm.taobao.org/mirrors/phantomjs
#-----------------------------------------------------------
#----------------------------
# Set Global packages path
#----------------------------
npm config set prefix "${INSTALL_PATH}/node-global"
npm config set cache "${INSTALL_PATH}/node-cache"
yarn config set cache-folder "${INSTALL_PATH}/yarn-cache"
#----------------------------
# Install Basic cli packages
#----------------------------
npm i -g yrm
yrm use taobao
#npm i -g pouchdb-server webpack yarn http-server j json dva-cli babel-cli code-push express-cli flow-bin  rundev
#x64
#npm i -g react-native-cli rnpm pm2 pouchdb-server npm webpack yrm http-server j json dva-cli babel-cli code-push express-cli flow-bin vue-cli rundev eslint tslint ts-node typescript cordova
#arm
npm i -g webpack http-server babel-cli pm2 typescript ts-node tslint eslint
#-----------------------