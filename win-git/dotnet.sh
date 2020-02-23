#!/bin/bash
#sudo apt update
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=dotnetrc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/dotnet

VERSION=2.1.6
SOFT_VERSION=release/${VERSION}xx

#SOFT_VERSION=master
SOFT_ARCH=x64

# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
case $(platform) in 
  win) PLATFORM=win;;
  linux) PLATFORM=linux;;
  macos) PLATFORM=osx;;
esac

case $(arch) in 
  amd64) SOFT_ARCH=x64;;
  386) SOFT_ARCH=x86;;
  armhf) SOFT_ARCH=arm;;
  aarch64) SOFT_ARCH=arm64;;
esac

SOFT_FILE_NAME=dotnet-sdk-latest-${PLATFORM}-${SOFT_ARCH}
SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
SOFT_URL=https://dotnetcli.blob.core.windows.net/dotnet/Sdk/${SOFT_VERSION}/${SOFT_FILE_PACK}
# init pwd
cd ~

#--------------------------------------
#安装 dotnet
#--------------------------------------
if [[ "$(dotnet --version)" != *${VERSION}* ]]; then

  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  $(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)

  rm -rf ${SOFT_HOME} && \
    mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME} 
fi
#--------------new .toolsrc-----------------------
export PATH=$PATH:${SOFT_HOME} 
export DOTNET_ROOT=${SOFT_HOME} 
echo 'export PATH=$PATH:'${SOFT_HOME} >${TOOLSRC}
echo 'export DOTNET_ROOT='${SOFT_HOME} >>${TOOLSRC}

#  ----windows bat----
# if [[ $PLATFORM == win ]]; then
if [[ $PLATFORM == not_win_ ]]; then
  setx DOTNET_ROOT $(cygpath -w ${SOFT_HOME})
  winENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
  echo $winENV
  setx Path "$winENV"
fi
