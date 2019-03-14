#!/bin/bash
# source
INSTALL_PATH=$HOME/tools
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=noderc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
SOFTHOME=$INSTALL_PATH/node
NODE_GLOBAL=$INSTALL_PATH/node-global
NODE_CACHE=$INSTALL_PATH/node-cache
NODE_VERSION=10.15.0
cd ~
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
if [[ "$(uname)" == *MINGW* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=win
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
  PLATFORM=linux
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=darwin
fi

if [[ "$(uname -a)" == *x86_64* ]]; then
  NODE_ARCH=x64
elif [[ "$(uname -a)" == *i686* ]]; then
  NODE_ARCH=x86
elif [[ "$(uname -a)" == *armv8l* ]]; then
  case $(getconf LONG_BIT) in 
    32) NODE_ARCH=armv7l;;
    64) NODE_ARCH=arm64;;
  esac
elif [[ "$(uname -a)" == *aarch64* ]]; then
  NODE_ARCH=arm64
elif [[ "$(uname -a)" == *armv7l* ]]; then
  NODE_ARCH=armv7l
fi

SOFT_FILE_NAME=node-v${NODE_VERSION}-${PLATFORM}-${NODE_ARCH}

if [[ ${PLATFORM} == win ]]; then
  SOFT_FILE_PACK=${SOFT_FILE_NAME}.zip
else
  SOFT_FILE_PACK=${SOFT_FILE_NAME}.tar.gz
fi
#--------------------------------------
#安装 nodejs
#--------------------------------------
if [[ "$(node --version)" != *${NODE_VERSION}* ]]; then
  if [ ! -d "${INSTALL_PATH}" ]; then
    mkdir $INSTALL_PATH
  fi

  if [ ! -f "${SOFT_FILE_PACK}" ]; then
    curl -o ${SOFT_FILE_PACK} http://cdn.npm.taobao.org/dist/node/v${NODE_VERSION}/${SOFT_FILE_PACK} 
  fi

  if [ ! -d "${SOFT_FILE_NAME}" ]; then
    if [[ ${PLATFORM} == win ]]; then
      unzip -q ${SOFT_FILE_PACK} -d ${SOFT_FILE_NAME}
    else
      mkdir ${SOFT_FILE_NAME}
      tar -xzf ${SOFT_FILE_PACK} -C ${SOFT_FILE_NAME}
    fi
  fi

  rm -rf $SOFTHOME && \
  mv ${SOFT_FILE_NAME} $SOFTHOME && \
  rm -rf ${SOFT_FILE_PACK}
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
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi
#windows下和linux下的不同
NODE_ROOT=${SOFTHOME}/${SOFT_FILE_NAME}
if [[ ${PLATFORM} == win ]]; then
  echo 'export PATH=$PATH:'${NODE_ROOT} > ${TOOLSRC}
  echo 'export PATH=$PATH:'${NODE_GLOBAL} >> ${TOOLSRC}
  export PATH=$PATH:$NODE_ROOT
  export PATH=$PATH:$NODE_GLOBAL
else
  echo 'export PATH=$PATH:'${NODE_ROOT}'/bin'> ${TOOLSRC}
  echo 'export PATH=$PATH:'${NODE_GLOBAL}'/bin' >> ${TOOLSRC}
  export PATH=$PATH:${NODE_ROOT}/bin
  export PATH=$PATH:${NODE_GLOBAL}/bin
fi
echo 'NPM_CONFIG_PREFIX='$NODE_GLOBAL >> ${TOOLSRC}
echo 'NPM_CONFIG_CACHE='$NODE_CACHE >> ${TOOLSRC}
echo 'YARN_CACHE_FOLDER='$INSTALL_PATH'/yarn-cache' >> ${TOOLSRC}
#-----env--------------------------------------------------
export NPM_CONFIG_PREFIX=$NODE_GLOBAL
export NPM_CONFIG_CACHE=$NODE_CACHE
export YARN_CACHE_FOLDER=$INSTALL_PATH/yarn-cache
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
npm i -g yarn webpack http-server babel-cli pm2 typescript ts-node tslint eslint
yarn config set cache-folder "${INSTALL_PATH}/yarn-cache"
#-----------------------
if [[ ${PLATFORM} == win ]]; then
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
