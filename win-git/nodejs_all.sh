#!/bin/bash
# source
INSTALL_PATH=$HOME/tools
NODE_HOME=$INSTALL_PATH/node
NODE_GLOBAL=$INSTALL_PATH/node-global
NODE_CACHE=$INSTALL_PATH/node-cache
NODE_VERSION=10.15.0
NODE_ARCH=x64
OS=win
NODE_FILE_NAME=node-v${NODE_VERSION}-${OS}-${NODE_ARCH}
NODE_FILE_PACK=${NODE_FILE_NAME}.zip
cd ~
#--------------------------------------
#安装 nodejs
#--------------------------------------
if [[ "$(node --version)" != *${NODE_VERSION}* ]]; then
  if [ ! -d "${INSTALL_PATH}" ]; then
    mkdir $INSTALL_PATH
  fi

  if [ ! -f "${NODE_FILE_PACK}" ]; then
    curl -o ${NODE_FILE_PACK} http://cdn.npm.taobao.org/dist/node/v${NODE_VERSION}/${NODE_FILE_PACK} 
  fi

  if [ ! -d "${NODE_FILE_NAME}" ]; then
    unzip -q ${NODE_FILE_PACK}
  fi
  rm -rf $NODE_HOME && \
  mv ${NODE_FILE_NAME} $NODE_HOME && \
  rm -rf ${NODE_FILE_PACK}
fi
#----------------------------
# Set Global packages path
#----------------------------
if [ ! -d "${NODE_GLOBAL}" ]; then
  mkdir ${NODE_GLOBAL}
fi
if [ ! -d "${NODE_CACHE}" ]; then
  mkdir ${NODE_CACHE}
fi
#--------------new .toolsrc-----------------------
if [[ $(cat ~/.bash_profile) != *toolsrc* ]]; then
  echo 'test -f ~/.toolsrc && . ~/.toolsrc' >> ~/.bash_profile
 fi
#windows下和linux下的不同
if [ ${OS}=='win' ]; then
  echo 'export PATH=$PATH:'${NODE_HOME} >~/.toolsrc
  echo 'export PATH=$PATH:'${NODE_GLOBAL} >> ~/.toolsrc
  export PATH=$PATH:$NODE_HOME
  export PATH=$PATH:$NODE_GLOBAL
elif [ ${OS}=='linux' ]; then
  echo 'export PATH=$PATH:'${NODE_HOME}'/bin'>~/.toolsrc
  echo 'export PATH=$PATH:'${NODE_GLOBAL}'/bin' >> ~/.toolsrc
  export PATH=$PATH:${NODE_HOME}/bin
  export PATH=$PATH:${NODE_GLOBAL}/bin
fi
echo 'NPM_CONFIG_PREFIX='$NODE_GLOBAL >> ~/.toolsrc
echo 'NPM_CONFIG_CACHE='$NODE_CACHE >> ~/.toolsrc
#-----env--------------------------------------------------
export NPM_CONFIG_PREFIX=$NODE_GLOBAL
export NPM_CONFIG_CACHE=$NODE_CACHE
export YARN_CACHE_FOLDER='$INSTALL_PATH'/yarn-cache
export ELECTRON_MIRROR=http://npm.taobao.org/mirrors/electron/
export SQLITE3_BINARY_SITE=http://npm.taobao.org/mirrors/sqlite3
export PHANTOMJS_CDNURL=http://npm.taobao.org/mirrors/phantomjs
#-----------------------------------------------------------
#----------------------------
# Set Global packages path
#----------------------------
npm config set prefix "${NODE_GLOBAL}"
npm config set cache "${NODE_CACHE}"
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
if [ ${OS}=='win' ]; then
  setx NPM_CONFIG_PREFIX $(cygpath -w $NPM_CONFIG_PREFIX)
  setx NPM_CONFIG_CACHE $(cygpath -w $NPM_CONFIG_CACHE)
  setx YARN_CACHE_FOLDER $(cygpath -w $YARN_CACHE_FOLDER)
  setx ELECTRON_MIRROR 'http://npm.taobao.org/mirrors/electron/'
  setx SQLITE3_BINARY_SITE 'http://npm.taobao.org/mirrors/sqlite3'
  setx PHANTOMJS_CDNURL 'http://npm.taobao.org/mirrors/phantomjs'

  winENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
  echo $winENV
  setx Path "$winENV"
fi