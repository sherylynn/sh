#!/bin/bash
#sudo apt update
lynn=$HOME

#常用工具
sudo apt install ssh tofrodos htop ncdu vim aria2 -y

#fromdos xxx

#更新docker源
sudo apt install apt-transport-https ca-certificates gnupg2  software-properties-common curl -y


curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/debian \
    buster \
    stable"
#安装并启动docker服务
sudo apt update
sudo apt install docker-ce -y
sudo service docker start
#建立docker用户
sudo groupadd docker
sudo usermod -aG docker $USER
sudo usermod -aG docker $(whoami)
sudo service docker restart

if [ ! -f "/usr/local/bin/docker-compose" ]; then
    sudo aria2c https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o docker-compose
    sudo install -t /usr/local/bin docker-compose
    rm -rf docker-compose
fi
#echo DOCKER_OPTS="--registry-mirror=https://mirror.ccs.tencentyun.com" |sudo tee -a /etc/default/docker
