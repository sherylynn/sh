#!/bin/bash
#sudo apt update
lynn=$HOME
INSTALL_PATH=$HOME/tools
#----------------------------
# Set Global packages path
#----------------------------
npm config set prefix "${INSTALL_PATH}/node-global"
npm config set cache "${INSTALL_PATH}/node-cache"
yarn config set cache-folder "${INSTALL_PATH}/yarn-cache"
#----------------------------
# Install Basic cli packages
#----------------------------
npm i -g yrm
yrm use taobao
#npm i -g pouchdb-server webpack yarn http-server j json dva-cli babel-cli code-push express-cli flow-bin  rundev
#x64
#npm i -g react-native-cli rnpm pm2 pouchdb-server npm webpack yrm http-server j json dva-cli babel-cli code-push express-cli flow-bin vue-cli rundev eslint tslint ts-node typescript cordova
#arm
npm i -g webpack http-server babel-cli pm2 typescript ts-node tslint eslint
#-----------------------
# git clone project
#-----------------------
#git clone https://github.com/sherylynn/sign_admin.git ~/sign_admin
#git clone https://github.com/sherylynn/sign_server.git ~/sign_server
#git clone https://github.com/sherylynn/sign_db.git ~/sign_db
#git clone https://github.com/sherylynn/plugins4rmmv.git ~/plugins4rmmv


sudo ln -s ${INSTALL_PATH}/node/bin/node /usr/local/bin/node
