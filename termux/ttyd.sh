#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
AUTHOR=tsl0922
NAME=ttyd
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
echo "soft version is $SOFT_VERSION"

case $(arch) in 
  amd64) SOFT_ARCH=x86_64;;
  386) SOFT_ARCH=386;;
  armhf) SOFT_ARCH=armhf;;
  aarch64) SOFT_ARCH=aarch64;;
esac
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
PLATFORM=$(platform)
SOFT_FILE_NAME=${NAME}
SOFT_FILE_PACK=${NAME}.${SOFT_ARCH}


SOFT_URL=https://github.com/${AUTHOR}/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}
if [[ $(platform) == *linux* ]]; then
  #$(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  
  rm -rf ${SOFT_HOME} && mkdir -p ${SOFT_HOME}
  #cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/${SOFT_FILE_NAME}
  #chmod 777 ${SOFT_HOME}/${SOFT_FILE_NAME}
  # 不用直接下载的ttyd了
  pkg install termux-services -y
  pkg install ttyd -y
  echo "export PATH=$SOFT_HOME:"'$PATH' > ${TOOLSRC}

  zsh ~/sh/termux/termux_service_ttyd.sh
  sh ~/sh/termux/termux_service_ttyd.sh
  sv-enable ttyd
fi
