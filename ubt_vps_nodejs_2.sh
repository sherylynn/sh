#!/bin/bash
#sudo apt update
lynn=$HOME

#----------------------------
# Set Global packages path
#----------------------------
npm config set prefix "/home/lynn/node-global"
npm config set cache "/home/lynn/node-cache"
yarn config set cache-folder "/home/lynn/yarn-cache"
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


sudo ln -s /home/lynn/node/bin/node /usr/local/bin/node