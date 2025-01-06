#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
AUTHOR=lzhiyong
NAME=termux-ndk
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
#SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
SOFT_VERSION=android-sdk
SDK_VERSION=android-sdk
SOFT_HOME=$(install_path)/${SOFT_VERSION}
echo "soft version is $SOFT_VERSION"

case $(arch) in
  amd64) SOFT_ARCH=x86_64 ;;
  386) SOFT_ARCH=386 ;;
  armhf) SOFT_ARCH=armhf ;;
  aarch64) SOFT_ARCH=aarch64 ;;
esac
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
PLATFORM=$(platform)
SOFT_FILE_NAME=${SOFT_VERSION}
#SOFT_FILE_PACK=${NAME}.${SOFT_ARCH}
SOFT_FILE_PACK=${SDK_VERSION}-aarch64.zip
SOFT_URL=https://github.com/${AUTHOR}/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}
if [[ $(platform) == *linux* ]]; then
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  $(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)

  rm -rf ${SOFT_HOME} &&
    mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}
  #chmod 777 ${SOFT_HOME}/${SOFT_FILE_NAME}
  echo "export PATH=$SOFT_HOME:"'$PATH' >${TOOLSRC}
fi
