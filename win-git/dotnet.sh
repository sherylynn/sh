#!/bin/bash
#sudo apt update
INSTALL_PATH=$HOME/tools
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=dotnetrc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
SOFT_HOME=$INSTALL_PATH/dotnet

VERSION=2.1.6
SOFT_VERSION=release/${VERSION}xx

#SOFT_VERSION=master
SOFT_ARCH=x64

# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
if [[ "$(uname)" == *MINGW* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=win
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
  PLATFORM=linux
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=osx
fi

if [[ "$(uname -a)" == *x86_64* ]]; then
  SOFT_ARCH=x64
elif [[ "$(uname -a)" == *i686* ]]; then
  SOFT_ARCH=x86
elif [[ "$(uname -a)" == *armv8l* ]]; then
  case $(getconf LONG_BIT) in 
    32) SOFT_ARCH=arm;;
    64) SOFT_ARCH=arm64;;
  esac
elif [[ "$(uname -a)" == *aarch64* ]]; then
  SOFT_ARCH=arm64
elif [[ "$(uname -a)" == *armv7l* ]]; then
  SOFT_ARCH=arm
fi

SOFT_FILE_NAME=dotnet-sdk-latest-${PLATFORM}-${SOFT_ARCH}

if [[ ${PLATFORM} == win ]]; then
  SOFT_FILE_PACK=${SOFT_FILE_NAME}.zip
else
  SOFT_FILE_PACK=${SOFT_FILE_NAME}.tar.gz
fi
# init pwd
cd ~

#--------------------------------------
#安装 dotnet
#--------------------------------------
if [[ "$(dotnet --version)" != *${VERSION}* ]]; then
  if [ ! -d "${INSTALL_PATH}" ]; then
    mkdir $INSTALL_PATH
  fi

  if [ ! -f "${SOFT_FILE_PACK}" ]; then
    curl -o ${SOFT_FILE_PACK} https://dotnetcli.blob.core.windows.net/dotnet/Sdk/${SOFT_VERSION}/${SOFT_FILE_PACK}
    echo dowload-url https://dotnetcli.blob.core.windows.net/dotnet/Sdk/${SOFT_VERSION}/${SOFT_FILE_PACK}
    #https://dotnetcli.blob.core.windows.net/dotnet/Sdk/release/2.1.6xx/dotnet-sdk-latest-win-x64.zip
  fi

  if [ ! -d "${SOFT_FILE_NAME}" ]; then
    if [ $PLATFORM == win ]; then
      unzip -q ${SOFT_FILE_PACK} -d ${SOFT_FILE_NAME}
    else
      mkdir ${SOFT_FILE_NAME}
      tar -xzf ${SOFT_FILE_PACK} -C ${SOFT_FILE_NAME}
    fi
  fi
  rm -rf ${SOFT_HOME} && \
  mv ${SOFT_FILE_NAME} ${SOFT_HOME} && \
  rm -rf ${SOFT_FILE_PACK}
fi
#--------------new .toolsrc-----------------------
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi
export PATH=$PATH:${SOFT_HOME} 
export DOTNET_ROOT=${SOFT_HOME} 
echo 'export PATH=$PATH:'${SOFT_HOME} >${TOOLSRC}
echo 'export DOTNET_ROOT='${SOFT_HOME} >>${TOOLSRC}

#  ----windows bat----
if [[ $PLATFORM == win ]]; then
  setx DOTNET_ROOT $(cygpath -w ${SOFT_HOME})
  winENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
  echo $winENV
  setx Path "$winENV"
fi
