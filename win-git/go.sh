#!/bin/bash
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=golangrc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/goroot
GO_ROOT=$SOFT_HOME/go
GO_PROXY=https://mirrors.aliyun.com/goproxy
GO_PATH=$(install_path)/gopath
GO_PATH_BIN=${GO_PATH}/bin
GO_ROOT_BIN=$GO_ROOT/bin
GO_VERSION=1.16
SOFT_ARCH=amd64
#SOFT_ARCH=arm64
#SOFT_ARCH=armv6l
#arm64

# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
case $(platform) in 
  win) PLATFORM=windows;;
  linux) PLATFORM=linux;;
  wslinux) PLATFORM=linux;;
  macos) PLATFORM=darwin;;
esac

case $(arch) in 
  amd64) SOFT_ARCH=amd64;;
  386) SOFT_ARCH=386;;
  armhf) SOFT_ARCH=armv6l;;
  aarch64) SOFT_ARCH=arm64;;
esac

while getopts 'v:a:sc' OPT; do
  case $OPT in
    v)
      GO_VERSION="$OPTARG";;
    a)
      SOFT_ARCH="$OPTARG";;
    s)
      Server="y";;
    c)
      Client="y";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

SOFT_FILE_NAME=go${GO_VERSION}.${PLATFORM}-${SOFT_ARCH}
SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
# init pwd
cd $HOME

shift $(($OPTIND - 1))
SOFT_URL=https://dl.google.com/go/${SOFT_FILE_PACK}
if [ "$(go version)" != "go version go${GO_VERSION} ${PLATFORM}/${SOFT_ARCH}" ]; then
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  $(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)
  
  rm -rf ${SOFT_HOME} && \
    mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME} 
fi
#--------------new .toolsrc-----------------------
export GOPATH=${GO_PATH}
export GOROOT=${GO_ROOT}
export PATH=$PATH:${GO_ROOT_BIN}
export PATH=$PATH:${GO_PATH_BIN}

echo 'export GOPATH='${GO_PATH}>${TOOLSRC}
echo 'export GOROOT='${GO_ROOT}>>${TOOLSRC}
echo 'export GOPROXY='${GO_PROXY}>>${TOOLSRC}
echo 'export PATH=$PATH:'${GO_ROOT_BIN}>>${TOOLSRC}
echo 'export PATH=$PATH:'${GO_PATH_BIN}>>${TOOLSRC}

#  ----windows bat----
if [[ $WIN_PATH  ]]; then
  if [[ $PLATFORM == windows ]]; then
    setx GOROOT $(cygpath -w ${GO_ROOT})
    setx GOPATH $(cygpath -w ${GO_PATH})
    windowsENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
    echo $windowsENV
    setx Path "$windowsENV"
  fi
fi
