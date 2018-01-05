#!/bin/bash

#常用工具
sudo yum update
sudo yum install epel-release -y
sudo yum install ssh dos2unix htop ncdu lrzsz vim -y

#更新docker源
sudo yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
sudo yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo

#安装并启动docker服务
sudo yum install docker-ce
sudo systemctl start docker

#加速
#echo DOCKER_OPTS="--registry-mirror=https://mirror.ccs.tencentyun.com" |sudo tee -a /etc/default/docker