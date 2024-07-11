#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
AUTHOR=mvdan
NAME=sh
REAL_NAME=shfmt
TOOLSRC_NAME=${REAL_NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${REAL_NAME}
SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
echo "soft version is $SOFT_VERSION"

case $(platform) in
  macos) PLATFORM=darwin;;
  win) PLATFORM=windows;;
  linux) PLATFORM=linux;;
esac
case $(arch) in 
  amd64) SOFT_ARCH=amd64;;
  386) SOFT_ARCH=386;;
  armhf) SOFT_ARCH=armhf;;
  aarch64) SOFT_ARCH=arm64;;
esac
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
SOFT_FILE_NAME=${REAL_NAME}
SOFT_FILE_PACK=${REAL_NAME}_${SOFT_VERSION}_${PLATFORM}_${SOFT_ARCH}

#https://github.com/mvdan/sh/releases/download/v3.8.0/shfmt_v3.8.0_linux_arm64
SOFT_URL=https://github.com/${AUTHOR}/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}
if [[ $(platform) == *linux* ]]; then
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  
  rm -rf ${SOFT_HOME} && mkdir -p ${SOFT_HOME}
  cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/${SOFT_FILE_NAME}
  chmod 777 ${SOFT_HOME}/${SOFT_FILE_NAME}

  #pkg install termux-services -y
  #pkg install ttyd -y
  echo "export PATH=$SOFT_HOME:"'$PATH' > ${TOOLSRC}

  #zsh ~/sh/termux/termux_service_ttyd.sh
  #sh ~/sh/termux/termux_service_ttyd.sh
  #sv-enable ttyd
fi
