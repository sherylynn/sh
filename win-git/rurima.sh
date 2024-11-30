#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=Moe-hacker
NAME=rurima
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
SOFT_ARCH=amd64

case $(platform) in
  macos) PLATFORM=macOS ;;
  win) PLATFORM=Windows ;;
  linux) PLATFORM=Linux ;;
esac

case $(arch) in
  amd64) SOFT_ARCH=x86_64 ;;
  386) SOFT_ARCH=32-bit ;;
  armhf) SOFT_ARCH=ARM_v6 ;;
  aarch64) SOFT_ARCH=aarch64 ;;
esac

#SOFT_FILE_NAME=${NAME}_${SOFT_VERSION:1}_${PLATFORM}_${SOFT_ARCH}
SOFT_FILE_NAME=${SOFT_ARCH}
#SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
SOFT_FILE_PACK=$SOFT_FILE_NAME.tar
COMMAND_NAME=$SOFT_FILE_NAME
# init pwd
cd $HOME
SOFT_URL=https://github.com/${AUTHOR}/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}

if [[ "$(${NAME} -v)" != *${SOFT_VERSION}* ]]; then
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  $(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)

  rm -rf ${SOFT_HOME} &&
    mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}
fi

SOFT_ROOT=${SOFT_HOME}

export PATH=$PATH:${SOFT_ROOT}
echo 'export PATH=$PATH:'${SOFT_ROOT} >${TOOLSRC}
