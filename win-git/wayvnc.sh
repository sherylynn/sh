#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=any1
NAME=wayvnc
LIB_NAME=neatvnc
LIB2_NAME=aml
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
LIB_HOME=$(install_path)/${LIB_NAME}
LIB2_HOME=$(install_path)/${LIB2_NAME}
SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
SOFT_EXE_HOME=${SOFT_HOME}/build
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
LIB_GIT_URL=https://github.com/${AUTHOR}/${LIB_NAME}
LIB2_GIT_URL=https://github.com/${AUTHOR}/${LIB2_NAME}

if [[ $(platform) == *linux* ]]; then
#  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  sudo apt install meson ninja-build pkg-config libdrm-dev -y
  sudo apt install xwayland weston -y
  git clone ${SOFT_GIT_URL} ${SOFT_HOME} 
  git clone ${LIB_GIT_URL} ${LIB_HOME} 
  git clone ${LIB2_GIT_URL} ${LIB2_HOME} 
  mkdir -p ${SOFT_HOME}/subprojects
  cd ${SOFT_HOME}/subprojects
  ln -s ../../${LIB_NAME} .
  ln -s ../../${LIB2_NAME} .
  mkdir -p ${LIB_HOME}/subprojects
  cd ${LIB_HOME}/subprojects
  ln -s ../../${LIB2_NAME} .
  cd ${SOFT_HOME}
  
  meson build
  ninja -C build
#  rm -rf ${SOFT_HOME} && mkdir -p ${SOFT_HOME}
#  cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/${SOFT_FILE_NAME}
#  chmod 777 ${SOFT_HOME}/${SOFT_FILE_NAME}
  echo "export PATH=$SOFT_EXE_HOME:"'$PATH' > ${TOOLSRC}
  cd ${SOFT_HOME}
  ./build/wayvnc 0.0.0.0
#  ./systemd_novnc.sh
fi
