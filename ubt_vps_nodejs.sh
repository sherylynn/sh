#!/bin/bash
#sudo apt update
lynn=$HOME
NODE_VERSION=7.10.0
#常用工具
sudo apt update
sudo apt install ssh tofrodos htop ncdu lrzsz vim -y

#base
sudo apt install software-properties-common \
    python-software-properties \
    wget \
    curl \
    git \
    build-essential -y
#--------------------------------------
#安装 nodejs
#--------------------------------------

#wget -q http://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz && \
#    tar -xzf node-v${NODE_VERSION}-linux-x64.tar.gz && \
#sudo mv node-v${NODE_VERSION}-linux-x64 /opt/node && \
#    rm node-v${NODE_VERSION}-linux-x64.tar.gz
#echo 'export PATH=$PATH:/opt/node/bin'>>~/.bashrc
#source ~/.bashrc

curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -
sudo apt install nodejs -y
#----------------------------
# Set Global packages path
#----------------------------
mkdir ~/node-global
mkdir ~/node-cache
mkdir ~/yarn-cache
sudo npm config set prefix "/home/lynn/node-global"
sudo npm config set cache "/home/lynn/node-cache"
#----------------------------
# Install Basic cli packages
#----------------------------
sudo npm i -g yrm
yrm use taobao
sudo npm i -g pouchdb-server webpack yarn yrm http-server j json dva-cli babel-cli code-push express-cli flow-bin  rundev
sudo yarn config set cache-folder "/home/lynn/yarn-cache"
#-----------------------
# git clone project
#-----------------------
git clone https://github.com/sherylynn/sign_admin.git
git clone https://github.com/sherylynn/sign_server.git
