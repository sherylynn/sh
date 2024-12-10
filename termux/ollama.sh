#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
AUTHOR=ollama
NAME=ollama
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
echo "soft version is $SOFT_VERSION"

pkg install git cmake golang clang -y

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

# uname Linux .bashrc uname Darwin MINGW64 .bash_profile

SOFT_GIT_URL=https://github.com/${AUTHOR}/${NAME}

if [[ $(platform) == *linux* ]]; then
  #  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  #  rm -rf ${SOFT_HOME} && mkdir -p ${SOFT_HOME}
  #  cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/${SOFT_FILE_NAME}
  #  chmod 777 ${SOFT_HOME}/${SOFT_FILE_NAME}
  cd ${SOFT_HOME}
  go generate ./...
  go build .
  echo "export PATH=$SOFT_HOME:"'$PATH' >${TOOLSRC}
#  ./systemd_novnc.sh
fi
