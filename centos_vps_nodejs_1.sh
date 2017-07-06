#!/bin/bash
#sudo apt update
lynn=$HOME
NODE_VERSION=7.10.0
#arm64 x64
#NODE_ARCH=armv7l
NODE_ARCH=x64
#NODE_ARCH=arm64
#常用工具
sudo yum update
sudo yum install epel-release -y
sudo yum install ssh dos2unix htop ncdu lrzsz vim -y

#base debian 9 has python3-software-properties instead of python-software-properties
sudo yum install wget curl git -y
sudo yum groupinstall "Development Tools" -y
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
