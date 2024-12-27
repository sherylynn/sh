#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
NAME=R
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION="b4337"
#SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
echo "soft version is $SOFT_VERSION"
#https://mirrors.tuna.tsinghua.edu.cn/CRAN/src/base/R-3/R-3.5.3.tar.gz

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
  sudo apt-get install r-base -y
  git clone https://github.com/sherylynn/toys ~/toys

  #httpgd  R package need
  sudo apt install libfontconfig1-dev libcairo2-dev libtiff-dev -y

  #treesitter-R
  sudo apt install cargo -y
elif [[ $(platform) == *darwin* ]]; then
  brew install R -y
  brew install libpng cairo libtiff -y
fi
