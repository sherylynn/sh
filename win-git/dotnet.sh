#!/bin/bash
#sudo apt update
lynn=$HOME
INSTALL_PATH=$HOME/tools
DOTNET_HOME=$INSTALL_PATH/dotnet

VERSION=2.1.6
DOTNET_VERSION=release/${VERSON}xx

#DOTNET_VERSION=master
DOTNET_ARCH=x64
PLATFORM=win
DOTNET_FILE_NAME=dotnet-sdk-latest-${PLATFORM}-${DOTNET_ARCH}
if [[ ${PLATFORM} == win ]]; then
  DOTNET_FILE_PACK=${DOTNET_FILE_NAME}.zip
else
  DOTNET_FILE_PACK=${DOTNET_FILE_NAME}.tar.gz
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

  if [ ! -f "${DOTNET_FILE_PACK}" ]; then
    curl -o ${DOTNET_FILE_PACK} https://dotnetcli.blob.core.windows.net/dotnet/Sdk/${DOTNET_VERSION}/${DOTNET_FILE_PACK}
  fi

  if [ ! -d "${DOTNET_FILE_NAME}" ]; then
    if [ $PLATFORM==win ]; then
      unzip -q ${DOTNET_FILE_PACK} -d ${DOTNET_FILE_NAME}
    else
      tar -xzf ${DOTNET_FILE_PACK} -C ${DOTNET_FILE_NAME}
    fi
  fi
  rm -rf ${DOTNET_HOME} && \
  mv ${DOTNET_FILE_NAME} ${DOTNET_HOME} && \
  rm -rf ${DOTNET_FILE_PACK}
fi
#--------------new .dotnetrc-----------------------
if [[ "$(cat ~/.bash_profile)" != *dotnetrc* ]]; then
  echo 'test -f ~/.dotnetrc && . ~/.dotnetrc' >> ~/.bash_profile
fi
export PATH=$PATH:${DOTNET_HOME} 
export DOTNET_ROOT=${DOTNET_HOME} 
echo 'export PATH=$PATH:'${DOTNET_HOME} >~/.dotnetrc
echo 'export DOTNET_ROOT='${DOTNET_HOME} >>~/.dotnetrc

#  ----windows bat----
if [[ $PLATFORM==win ]]; then
  setx DOTNET_ROOT $(cygpath -w ${DOTNET_HOME})
  winENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
  echo $winENV
  setx Path "$winENV"
fi