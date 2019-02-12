#!/bin/bash
#sudo apt update
lynn=$HOME
INSTALL_PATH=$HOME/tools
V2RAY_HOME=$INSTALL_PATH/v2ray

VERSION=4.11.0
V2RAY_VERSION=release/${VERSION}xx

#V2RAY_VERSION=master
V2RAY_ARCH=x64
PLATFORM=win
V2RAY_FILE_NAME=dotnet-sdk-latest-${PLATFORM}-${V2RAY_ARCH}
if [[ ${PLATFORM} == win ]]; then
  V2RAY_FILE_PACK=${V2RAY_FILE_NAME}.zip
else
  V2RAY_FILE_PACK=${V2RAY_FILE_NAME}.tar.gz
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

  if [ ! -f "${V2RAY_FILE_PACK}" ]; then
    curl -o ${V2RAY_FILE_PACK} https://dotnetcli.blob.core.windows.net/dotnet/Sdk/${V2RAY_VERSION}/${V2RAY_FILE_PACK}
    echo dowload-url https://dotnetcli.blob.core.windows.net/dotnet/Sdk/${V2RAY_VERSION}/${V2RAY_FILE_PACK}
    #https://github.com/v2ray/v2ray-core/releases/download/v4.11.0/v2ray-linux-arm.zip
    #https://github.com/v2ray/v2ray-core/releases/download/v4.11.0/v2ray-windows-64.zip
    #https://dotnetcli.blob.core.windows.net/dotnet/Sdk/release/2.1.6xx/dotnet-sdk-latest-win-x64.zip
  fi

  if [ ! -d "${V2RAY_FILE_NAME}" ]; then
    if [ $PLATFORM==win ]; then
      unzip -q ${V2RAY_FILE_PACK} -d ${V2RAY_FILE_NAME}
    else
      tar -xzf ${V2RAY_FILE_PACK} -C ${V2RAY_FILE_NAME}
    fi
  fi
  rm -rf ${V2RAY_HOME} && \
  mv ${V2RAY_FILE_NAME} ${V2RAY_HOME} && \
  rm -rf ${V2RAY_FILE_PACK}
fi
#--------------new .dotnetrc-----------------------
if [[ "$(cat ~/.bash_profile)" != *dotnetrc* ]]; then
  echo 'test -f ~/.dotnetrc && . ~/.dotnetrc' >> ~/.bash_profile
fi
export PATH=$PATH:${V2RAY_HOME} 
export V2RAY_ROOT=${V2RAY_HOME} 
echo 'export PATH=$PATH:'${V2RAY_HOME} >~/.dotnetrc
echo 'export V2RAY_ROOT='${V2RAY_HOME} >>~/.dotnetrc

#  ----windows bat----
if [[ $PLATFORM==win ]]; then
  setx V2RAY_ROOT $(cygpath -w ${V2RAY_HOME})
  winENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
  echo $winENV
  setx Path "$winENV"
fi
