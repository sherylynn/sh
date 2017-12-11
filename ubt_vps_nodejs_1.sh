#!/bin/bash
#sudo apt update
lynn=$HOME
NODE_VERSION=8.9.3
#arm64 x64
#NODE_ARCH=armv7l
NODE_ARCH=x64
#NODE_ARCH=arm64
#NODE_ARCH=x86
#常用工具
sudo apt update
sudo apt install ssh tofrodos htop ncdu lrzsz vim -y

#base debian 9 has python3-software-properties instead of python-software-properties
sudo apt install software-properties-common -y
sudo apt install wget curl git build-essential -y
sudo apt install python-software-properties -y
sudo apt install python -y
#--------------------------------------
#安装 nodejs
#--------------------------------------

wget -q http://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz && \
    tar -xzf node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz && \
sudo mv node-v${NODE_VERSION}-linux-${NODE_ARCH} /home/lynn/node && \
    rm node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz
echo 'export PATH=$PATH:/home/lynn/node/bin'>>~/.bashrc
source ~/.bashrc

#curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -
#sudo apt install nodejs -y

#----------------------------
# Set Global packages path
#----------------------------
mkdir ~/node-global
mkdir ~/node-cache
mkdir ~/yarn-cache
echo 'export PATH="~/node-global/bin:$PATH"' >> ~/.bashrc
echo 'NPM_CONFIG_PREFIX=~/node-global' >> ~/.bashrc
echo 'NPM_CONFIG_CACHE=~/node-cache' >> ~/.bashrc
echo 'YARN_CACHE_FOLDER=~/yarn-cache' >> ~/.bashrc
source ~/.bashrc
