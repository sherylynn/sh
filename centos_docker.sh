#!/bin/bash

#常用工具
sudo yum update -y
sudo yum install epel-release -y
sudo yum install ssh dos2unix htop ncdu lrzsz vim -y

#更新docker源
sudo yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
sudo yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo -y

#安装并启动docker服务
sudo yum install -y docker-ce
sudo systemctl start docker

#安装docker-compose
if [ ! -f "/usr/local/bin/docker-compose" ]; then
    sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    sudo chmod 777 /usr/local/bin/docker-compose
fi

#加速
#echo DOCKER_OPTS="--registry-mirror=https://mirror.ccs.tencentyun.com" |sudo tee -a /etc/default/docker