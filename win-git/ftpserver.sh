#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=fclairamb
NAME=ftpserver
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
SOFT_ARCH=amd64
#SOFT_ARCH=arm
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
case $(platform) in
  macos) PLATFORM=darwin;;
  win) PLATFORM=windows;;
  linux) PLATFORM=linux;;
esac

case $(arch) in 
  amd64) SOFT_ARCH=amd64;;
  386) SOFT_ARCH=386;;
  armhf) SOFT_ARCH=arm;;
  aarch64) SOFT_ARCH=arm64;;
esac

#ftpserver-linux-arm64

SOFT_FILE_NAME=${NAME}-${PLATFORM}-${SOFT_ARCH}
SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME bin )
COMMAND_NAME=$SOFT_FILE_NAME
# init pwd
#cd $HOME
SOFT_URL=https://github.com/${AUTHOR}/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}

if [[ "$(${NAME} -v)" != *${SOFT_VERSION}* ]]; then
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  $(cache_unpacker $SOFT_FILE_PACK $NAME)
  
  rm -rf ${SOFT_HOME} && \
    mv $(cache_folder)/${NAME} ${SOFT_HOME} 
fi

SOFT_ROOT=${SOFT_HOME}

export PATH=$PATH:${SOFT_ROOT}
echo 'export PATH=$PATH:'${SOFT_ROOT}>${TOOLSRC}

test ! -f ${BASH_DIR}/${NAME}.json && cp $(realScriptPathDir )/${NAME}.sample.json ${BASH_DIR}/${NAME}.json
