#!/bin/bash
#sudo apt update
lynn=/home/lynn

#常用工具
sudo apt install ssh tofrodos htop ncdu vim -y

#fromdos xxx

#更新docker源
sudo apt install apt-transport-https ca-certificates software-properties-common curl -y


curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
#安装并启动docker服务
sudo apt update
sudo apt install docker-ce -y
sudo service docker start
#建立docker用户
sudo groupadd docker
sudo usermod -aG docker $USER
sudo service docker restart

echo DOCKER_OPTS="--registry-mirror=https://mirror.ccs.tencentyun.com" |sudo tee -a /etc/default/docker