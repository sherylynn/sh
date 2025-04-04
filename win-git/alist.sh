#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=AlistGo
NAME=alist
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
SOFT_ARCH=amd64
Server=n
Client=n
Just_Install=n
#SOFT_ARCH=arm
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
case $(platform) in
  macos) PLATFORM=darwin ;;
  win) PLATFORM=windows ;;
  linux) PLATFORM=linux ;;
esac

case $(arch) in
  amd64) SOFT_ARCH=amd64 ;;
  386) SOFT_ARCH=386 ;;
  armhf) SOFT_ARCH=armv-7 ;;
  aarch64) SOFT_ARCH=arm64 ;;
esac

#alist-linux-amd64.tar.gz
#https://github.com/AlistGo/alist/releases/download/v3.42.0/alist-linux-amd64.tar.gz
SOFT_FILE_NAME=${NAME}-${PLATFORM}-${SOFT_ARCH}
SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
COMMAND_NAME=$SOFT_FILE_NAME
# init pwd
#cd $HOME
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

#test ! -f ${BASH_DIR}/alist.config && cp $(realScriptPathDir)/webdav.sample.yaml ${BASH_DIR}/webdav.yaml

#webdav -c /root/tools/rc/weddav.yaml
#有专门的 server_webdav.sh 和 systemd_webdav.sh

#alist --data ~/data admin set NEW_PASSWORD
#设置密码
