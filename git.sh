#!/bin/bash
#git config --global http.proxy http://127.0.0.1:10808
git config --global user.name "sherylynn"
git config --global user.email "352281674@qq.com"
git config --global credential.helper cache
git config --global credential.helper 'cache --timeout=2678400'
git config --global credential.helper store
git config --global pull.rebase false

git config --global alias.gco 'checkout .'
git config --global alias.gca 'commit -a'
git config --global alias.gaa 'add --all'
git config --global alias.gcf 'commit -m "fix" -a'
#git config --global alias.gc. 'checkout .'
git config --global alias.gs 'status'
git config --global alias.gp 'push'
git config --global alias.gl 'pull'
git config --global alias.F 'pull'

git config --global core.editor vim
# for crlf
git config --global core.autocrlf input

#echo "alias lynn ='git clone https://github/sherylynn/'" >> ~/.bashrc
#-----------------------
# git clone project
#-----------------------
#git clone https://github.com/sherylynn/sign_admin.git ~/sign_admin
#git clone https://github.com/sherylynn/sign.git ~/sign
#git clone https://github.com/sherylynn/sign_server.git ~/sign_server
#git clone https://github.com/sherylynn/sign_db.git ~/sign_db
#git clone --recursive https://github.com/sherylynn/plugins4rmmv ~/plugins4rmmv
#git clone https://github.com/sherylynn/server4rmmv.git ~/server4rmmv
