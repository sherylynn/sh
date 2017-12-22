#!/bin/bash
#sudo apt update
lynn=~

#----------------------------
# Set Global packages path
#----------------------------
npm config set prefix "~/node-global"
npm config set cache "~/node-cache"
yarn config set cache-folder "~/yarn-cache"
#----------------------------
# Install Basic cli packages
#----------------------------
npm i -g yrm
yrm use taobao
#npm i -g pouchdb-server webpack yarn http-server j json dva-cli babel-cli code-push express-cli flow-bin  rundev
npm i -g webpack yarn http-server j json dva-cli babel-cli code-push express-cli vue-cli pm2
#-----------------------
# git clone project
#-----------------------
git clone https://github.com/sherylynn/sign_admin.git ~/sign_admin
git clone https://github.com/sherylynn/sign_server.git ~/sign_server
git clone https://github.com/sherylynn/sign_db.git ~/sign_db
