#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=ollama
NAME=ollama
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
#SOFT_ARCH=amd64
SOFT_ARCH=arm64

case $(platform) in
  macos) PLATFORM=darwin ;;
  win) PLATFORM=windows ;;
  linux) PLATFORM=linux ;;
esac

case $(arch) in
  amd64) SOFT_ARCH=x86_64 ;;
  386) SOFT_ARCH=32-bit ;;
  armhf) SOFT_ARCH=ARM_v6 ;;
  aarch64) SOFT_ARCH=arm64 ;;
esac

SOFT_FILE_NAME=${NAME}-${PLATFORM}-${SOFT_ARCH}
#SOFT_FILE_NAME=${SOFT_ARCH}
#SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
SOFT_FILE_PACK=$SOFT_FILE_NAME.tgz
COMMAND_NAME=$SOFT_FILE_NAME
# init pwd
cd $HOME

#https://github.com/ollama/ollama/releases/download/v0.5.1/ollama-linux-arm64.tgz
SOFT_URL=https://github.com/${AUTHOR}/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}

if [[ "$(${NAME} -v)" != *${SOFT_VERSION}* ]]; then
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  #解压稍微有点不一样
  $(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)
  #tar -xzvf $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}
  rm -rf ${SOFT_HOME} &&
    mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}
  #mv ${SOFT_HOME}/${SOFT_FILE_NAME}/${SOFT_FILE_NAME} ${SOFT_HOME}/${NAME}
  #chmod 777 ${SOFT_HOME}/${NAME}
fi

SOFT_ROOT=${SOFT_HOME}/bin

export PATH=$PATH:${SOFT_ROOT}
echo 'export PATH=$PATH:'${SOFT_ROOT} >${TOOLSRC}
