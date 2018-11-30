#!/bin/bash
#sudo apt update
lynn=$HOME
INSTALL_PATH=$HOME/tools
DOTNET_PATH=$INSTALL_PATH/dotnet
rm -rf $DOTNET_PATH
mkdir -p $DOTNET_PATH
DOTNET_VERSION=release/2.1.4xx
#DOTNET_VERSION=master
DOTNET_ARCH=arm
wget  https://dotnetcli.blob.core.windows.net/dotnet/Sdk/${DOTNET_VERSION}/dotnet-sdk-latest-linux-${DOTNET_ARCH}.tar.gz
#axel -n 10 https://dotnetcli.blob.core.windows.net/dotnet/Sdk/${DOTNET_VERSION}/dotnet-sdk-latest-linux-${DOTNET_ARCH}.tar.gz
tar -xzf dotnet-sdk-latest-linux-${DOTNET_ARCH}.tar.gz -C ${DOTNET_PATH}
rm -rf dotnet-sdk-latest-linux-${DOTNET_ARCH}.tar.gz
export PATH=$PATH:${DOTNET_PATH} 
echo 'export PATH=$PATH:'${DOTNET_PATH} >>~/.bashrc
echo 'export DOTNET_ROOT='${DOTNET_PATH} >>~/.bashrc
