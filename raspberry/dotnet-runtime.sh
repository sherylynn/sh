#!/bin/bash
#sudo apt update
lynn=$HOME
INSTALL_PATH=$HOME/tools
DOTNET_PATH=$INSTALL_PATH/dotnet
rm -rf $DOTNET_PATH
mkdir -p $DOTNET_PATH
DOTNET_VERSION=2.1
DOTNET_ARCH=arm
axel -n 10 https://dotnetcli.blob.core.windows.net/dotnet/Runtime/release/${DOTNET_VERSION}/dotnet-runtime-latest-linux-${DOTNET_ARCH}.tar.gz 
#axel -n 10 https://dotnetcli.blob.core.windows.net/dotnet/Runtime/master/dotnet-runtime-latest-linux-${NODE_ARCH}.tar.gz && \
  tar -xzf dotnet-runtime-latest-linux-${DOTNET_ARCH}.tar.gz -C ${DOTNET_PATH}
rm -rf dotnet-runtime-latest-linux-${DOTNET_ARCH}.tar.gz
export PATH=$PATH:${DOTNET_PATH} 
echo 'export PATH=$PATH:'${DOTNET_PATH} >>~/.bashrc
echo 'export DOTNET_ROOT='${DOTNET_PATH} >>~/.bashrc
