#!/bin/bash
#sudo apt update
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=dotnetrc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/dotnet
SOFT_TOOL_HOME=$HOME/.dotnet/tools
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

LIB_FILE_NAME=dotnet-install.sh
LIB_URL=https://dot.net/v1/dotnet-install.sh
#SOFT_URL=https://dotnetcli.azureedge.net/dotnet/Sdk/
# init pwd
cd ~

#--------------------------------------
#安装 dotnet
#--------------------------------------
$(cache_downloader $LIB_FILE_PACK $LIB_URL)
chmod 777 $(cache_folder)/${LIB_FILE_NAME}
$(cache_folder)/${LIB_FILE_NAME} --install-dir ${SOFT_HOME} --channel Current --architecture ${SOFT_ARCH}

#--------------new .toolsrc-----------------------
export PATH=$PATH:${SOFT_HOME}:${SOFT_TOOL_HOME}
export DOTNET_ROOT=${SOFT_HOME} 
echo 'export PATH=$PATH:'${SOFT_HOME}:${SOFT_TOOL_HOME} >${TOOLSRC}
echo 'export DOTNET_ROOT='${SOFT_HOME} >>${TOOLSRC}

dotnet tool install --global dotnet-warp
#  ----windows bat----
# if [[ $PLATFORM == win ]]; then
if [[ $PLATFORM == not_win_ ]]; then
  setx DOTNET_ROOT $(cygpath -w ${SOFT_HOME})
  winENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
  echo $winENV
  setx Path "$winENV"
fi
