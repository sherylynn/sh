#!/bin/bash
#sudo apt update
lynn=/home/lynn

#常用工具
sudo apt install ssh tofrodos htop ncdu vim -y

#fromdos xxx

#更新docker源
sudo apt install apt-transport-https ca-certificates software-properties-common curl -y
curl -fsSL https://apt.dockerproject.org/gpg | sudo apt-key add -
sudo add-apt-repository \
       "deb https://apt.dockerproject.org/repo/ \
       ubuntu-$(lsb_release -cs) \
       main"
       
#安装并启动docker服务
sudo apt update
sudo apt install docker-engine -y
sudo service docker start
#建立docker用户
sudo groupadd docker
sudo usermod -aG docker $USER
sudo service docker restart
