#!/bin/bash
#sudo apt update
lynn=$HOME
INSTALL_PATH=$HOME/tools
DOTNET_PATH=$INSTALL_PATH/dotnet
rm -rf $DOTNET_PATH
mkdir -p $DOTNET_PATH
DOTNET_ARCH=arm
axel -n 10 https://dotnetcli.blob.core.windows.net/dotnet/Sdk/master/dotnet-sdk-latest-linux-${DOTNET_ARCH}.tar.gz
tar -xzf dotnet-sdk-latest-linux-${DOTNET_ARCH}.tar.gz -C ${DOTNET_PATH}
rm -rf dotnet-sdk-latest-linux-${DOTNET_ARCH}.tar.gz
export PATH=$PATH:${DOTNET_PATH} 
echo 'export PATH=$PATH:'${DOTNET_PATH} >>~/.bashrc
