#!/bin/bash
# source
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=noderc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/node
NODE_GLOBAL=$(install_path)/node-global
NODE_CACHE=$(install_path)/node-cache
#SOFT_VERSION=16.15.1
SOFT_VERSION=22.11.0
cd ~
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
PLATFORM=$(platform)
if [[ "$PLATFORM" == "macos" ]]; then
  PLATFORM=darwin
elif [[ "$PLATFORM" == "wslinux" ]]; then
  PLATFORM=linux
fi

case $(arch) in
  amd64) SOFT_ARCH=x64 ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=armv7l ;;
  aarch64) SOFT_ARCH=arm64 ;;
esac

SOFT_FILE_NAME=node-v${SOFT_VERSION}-${PLATFORM}-${SOFT_ARCH}

SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)

#SOFT_URL=http://cdn.npmmirror.com/dist/node/v${SOFT_VERSION}/${SOFT_FILE_PACK}
SOFT_URL=https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/v${SOFT_VERSION}/${SOFT_FILE_PACK}
#--------------------------------------
#安装 nodejs
#--------------------------------------
if [[ "$(node --version)" != *${SOFT_VERSION}* ]]; then
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  $(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)

  rm -rf $SOFT_HOME &&
    mv $(cache_folder)/${SOFT_FILE_NAME} $SOFT_HOME
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
#windows下和linux下的不同
NODE_ROOT=${SOFT_HOME}/${SOFT_FILE_NAME}
if [[ ${PLATFORM} == win ]]; then
  echo 'export PATH=$PATH:'${NODE_ROOT} >${TOOLSRC}
  echo 'export PATH=$PATH:'${NODE_GLOBAL} >>${TOOLSRC}
  export PATH=$PATH:$NODE_ROOT
  export PATH=$PATH:$NODE_GLOBAL
  export NODE_SKIP_PLATFORM_CHECK=1
else
  echo 'export PATH=$PATH:'${NODE_ROOT}'/bin' >${TOOLSRC}
  echo 'export PATH=$PATH:'${NODE_GLOBAL}'/bin' >>${TOOLSRC}
  export PATH=$PATH:${NODE_ROOT}/bin
  export PATH=$PATH:${NODE_GLOBAL}/bin
fi
echo 'NPM_CONFIG_PREFIX='$NODE_GLOBAL >>${TOOLSRC}
echo 'NPM_CONFIG_CACHE='$NODE_CACHE >>${TOOLSRC}
echo 'YARN_CACHE_FOLDER='$(install_path)'/yarn-cache' >>${TOOLSRC}
echo 'export NODE_SKIP_PLATFORM_CHECK=1' >>${TOOLSRC}
#-----env--------------------------------------------------
export NPM_CONFIG_PREFIX=$NODE_GLOBAL
export NPM_CONFIG_CACHE=$NODE_CACHE
export YARN_CACHE_FOLDER=$(install_path)/yarn-cache
export ELECTRON_MIRROR=http://npmmirror.com/mirrors/electron/
export SQLITE3_BINARY_SITE=http://npmmirror.com/mirrors/sqlite3
export PHANTOMJS_CDNURL=http://npmmirror.com/mirrors/phantomjs
#-----------------------------------------------------------
#----------------------------
# Set Global packages path
#----------------------------
npm config set prefix "${NODE_GLOBAL}"
npm config set cache "${NODE_CACHE}"
yarn config set cache-folder "$(install_path)/yarn-cache"
#----------------------------
# Install Basic cli packages
#----------------------------
#npm i -g yrm --registry=https://registry.npmmirror.com
#npm i nrm --registry=https://registry.npmmirror.com --location=global
npm i yrm --registry=https://registry.npmmirror.com --location=global

#npm i cnpm --registry=https://registry.npmmirror.com --location=global
yrm add newtaobao https://registry.npmmirror.com
yrm use newtaobao
echo "con.nvim:registry=https://registry.npmmirror.com" >>~/.npmrc
#nrm use taobao
#npm i -g pouchdb-server webpack yarn http-server j json dva-cli babel-cli code-push express-cli flow-bin  rundev
#x64
#npm i -g react-native-cli rnpm pm2 pouchdb-server npm webpack yrm http-server j json dva-cli babel-cli code-push express-cli flow-bin vue-cli rundev eslint tslint ts-node typescript cordova
#arm
cnpm i yarn webpack http-server babel-cli pm2 typescript ts-node tslint eslint --location=global
yarn config set cache-folder "$(install_path)/yarn-cache"
#-----------------------
#if [[ $WIN_PATH ]]; then
#  if [[ ${PLATFORM} == win ]]; then
#    setx NPM_CONFIG_PREFIX $(cygpath -w $NPM_CONFIG_PREFIX)
#    setx NPM_CONFIG_CACHE $(cygpath -w $NPM_CONFIG_CACHE)
#    setx YARN_CACHE_FOLDER $(cygpath -w $YARN_CACHE_FOLDER)
#    setx ELECTRON_MIRROR 'http://npmmirror.com/mirrors/electron/'
#    setx SQLITE3_BINARY_SITE 'http://npmmirror.com/mirrors/sqlite3'
#    setx PHANTOMJS_CDNURL 'http://npmmirror.com/mirrors/phantomjs'
#
#    winENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
#    echo $winENV
#    setx Path "$winENV"
#  fi
#fi
