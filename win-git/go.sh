#!/bin/bash
INSTALL_PATH=$HOME/tools
GO_HOME=$INSTALL_PATH/goroot
GO_ROOT=$GO_HOME/go
GO_PATH=$INSTALL_PATH/gopath
GO_PATH_BIN=${GO_PATH}/bin
GO_ROOT_BIN=$GO_ROOT/bin
GO_VERSION=1.10
GO_ARCH=amd64
#GO_ARCH=arm64
#GO_ARCH=armv6l
#arm64

# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
if [[ "$(uname)" == *MINGW* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=windows
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
  PLATFORM=linux
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=osx
fi

if [[ "$(uname -a)" == *x86_64* ]]; then
  GO_ARCH=amd64
elif [[ "$(uname -a)" == *i686* ]]; then
  GO_ARCH=386
elif [[ "$(uname -a)" == *armv8l* ]]; then
  GO_ARCH=arm64
elif [[ "$(uname -a)" == *aarch64* ]]; then
  GO_ARCH=arm64
fi
while getopts 'v:a:sc' OPT; do
  case $OPT in
    v)
      GO_VERSION="$OPTARG";;
    a)
      GO_ARCH="$OPTARG";;
    s)
      Server="y";;
    c)
      Client="y";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

GO_FILE_NAME=go${GO_VERSION}.${PLATFORM}-${GO_ARCH}
if [[ ${PLATFORM} == windows ]]; then
  GO_FILE_PACK=${GO_FILE_NAME}.zip
else
  GO_FILE_PACK=${GO_FILE_NAME}.tar.gz
fi
# init pwd
cd $HOME

shift $(($OPTIND - 1))

if [ "$(go version)" != "go version go${GO_VERSION} ${PLATFORM}/${GO_ARCH}" ]; then
  if [ ! -d "${INSTALL_PATH}" ]; then
    mkdir $INSTALL_PATH
  fi

  if [ ! -f "${GO_FILE_PACK}" ]; then
    echo ${GO_FILE_PACK}
    curl -o ${GO_FILE_PACK} https://dl.google.com/go/${GO_FILE_PACK}
  fi
  
  if [ ! -d "${GO_FILE_NAME}" ]; then
    if [ ${PLATFORM} == windows ]; then
      unzip -q ${GO_FILE_PACK} -d ${GO_FILE_NAME}
    else
      mkdir ${GO_FILE_NAME}
      tar -xzf ${GO_FILE_PACK} -C ${GO_FILE_NAME}
    fi
  fi
  rm -rf ${GO_HOME} && \
  mv ${GO_FILE_NAME} ${GO_HOME} && \
  rm -rf ${GO_FILE_PACK}
fi
#--------------new .toolsrc-----------------------
if [[ "$(cat ${BASH_FILE})" != *golangrc* ]]; then
  echo 'test -f ~/.golangrc && . ~/.golangrc' >> ${BASH_FILE}
fi

export GOPATH=${GO_PATH}
export GOROOT=${GO_ROOT}
export PATH=$PATH:${GO_ROOT_BIN}
export PATH=$PATH:${GO_PATH_BIN}

echo 'export GOPATH='${GO_PATH}>~/.golangrc
echo 'export GOROOT='${GO_ROOT}>>~/.golangrc
echo 'export PATH=$PATH:'${GO_ROOT_BIN}>>~/.golangrc
echo 'export PATH=$PATH:'${GO_PATH_BIN}>>~/.golangrc

#  ----windows bat----
if [[ $PLATFORM == windows ]]; then
  setx GOROOT $(cygpath -w ${GO_ROOT})
  setx GOPATH $(cygpath -w ${GO_PATH})
  windowsENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
  echo $windowsENV
  setx Path "$windowsENV"
fi
