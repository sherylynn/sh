#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
TOOLSRC_NAME=golangrc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/goroot
GO_ROOT=$SOFT_HOME/go
GO_PATH=$(install_path)/gopath
GO_PATH_BIN=${GO_PATH}/bin
GO_ROOT_BIN=$GO_ROOT/bin
GO_VERSION=1.14
SOFT_ARCH=amd64
#SOFT_ARCH=arm64
#SOFT_ARCH=armv6l
#arm64
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
case $(platform) in 
  win) PLATFORM=windows;;
  linux) PLATFORM=linux;;
  macos) PLATFORM=darwin;;
esac

case $(arch) in 
  amd64) SOFT_ARCH=amd64;;
  386) SOFT_ARCH=386;;
  armhf) SOFT_ARCH=armv6l;;
  aarch64) SOFT_ARCH=arm64;;
esac


# init pwd
cd $HOME
mkdir -p $GOPATH
mkdir -p $GOROOT
#--------------new .toolsrc-----------------------
export GOPATH=${GO_PATH}
export GOROOT=${GO_ROOT}
export PATH=$PATH:${GO_ROOT_BIN}
export PATH=$PATH:${GO_PATH_BIN}

echo 'export GOPATH='${GO_PATH}>${TOOLSRC}
echo 'export GOROOT='${GO_ROOT}>>${TOOLSRC}
echo 'export PATH=$PATH:'${GO_ROOT_BIN}>>${TOOLSRC}
echo 'export PATH=$PATH:'${GO_PATH_BIN}>>${TOOLSRC}

