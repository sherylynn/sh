#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=novnc
NAME=noVNC
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
SOFT_FILE_NAME=${SOFT_VERSION}
SOFT_FILE_PACK=${SOFT_FILE_NAME}.zip

SOFT_URL=https://github.com/${AUTHOR}/${NAME}/archive/refs/tags/${SOFT_VERSION}
SOFT_GIT_URL=https://github.com/${AUTHOR}/${NAME}

if [[ $(platform) == *linux* ]]; then
#  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  git clone ${SOFT_GIT_URL} ${SOFT_HOME} 
#  rm -rf ${SOFT_HOME} && mkdir -p ${SOFT_HOME}
#  cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/${SOFT_FILE_NAME}
#  chmod 777 ${SOFT_HOME}/${SOFT_FILE_NAME}
  echo "export PATH=$SOFT_HOME:"'$PATH' > ${TOOLSRC}
  cd ${SOFT_HOME}/../../
  rm -rf /tmp/.X*
  rm -rf /tmp/.x*
  vncserver -kill :0
  vncserver -geometry 1920x966 :0
  ./tools/noVNC/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10000

#  ./systemd_novnc.sh
fi
