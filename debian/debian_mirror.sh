#!/bin/bash
#sudo vi /etc/apt/sources.list +%s#deb.debian.org#mirrors.ustc.edu.cn#g +wq!
#sudo vi /etc/apt/sources.list +%s#mirrors.ustc.edu.cn#mirror.aliyun.com#g +wq!
if [[ $1 = "" ]]; then
    echo "edit default sources.list"
    sudo vi /etc/apt/sources.list +%s#deb.debian.org#mirrors.tuna.tsinghua.edu.cn#g +wq!
    sudo vi /etc/apt/sources.list +%s#security.debian.org#mirrors.tuna.tsinghua.edu.cn#g +wq!
    sudo vi /etc/apt/sources.list '+%s#\[signed-by="/usr/share/keyrings/debian-archive-keyring.gpg"\]##g' +wq! 
else
    echo "edit $1"
    sudo vi $1 +%s#deb.debian.org#mirrors.tuna.tsinghua.edu.cn#g +wq!
    sudo vi $1 +%s#security.debian.org#mirrors.tuna.tsinghua.edu.cn#g +wq!
    sudo vi $1 '+%s#\[signed-by="/usr/share/keyrings/debian-archive-keyring.gpg"\]##g' +wq!
fi
#sudo vi /etc/apt/sources.list +%s#security.debian.org#mirror.aliyun.com#g +wq!
#sudo vi /etc/apt/sources.list +%s/main$/main\ contrib\ non-free/g +wq!
#sudo vi /etc/apt/sources.list +%s/mirror\./mirrors/g +wq!
#sudo vi /etc/apt/sources.list +%s/mirrorsaliyun/mirrors\.aliyun/g +wq!
#sudo vi /etc/apt/sources.list +%s#mirror.aliyun.com#mirrors.ustc.edu.cn#g +wq!
#sudo vi /etc/apt/sources.list +%s#deb.debian.org#mirrors.ustc.edu.cn#g +wq!
#sudo vi /etc/apt/sources.list +%s/stretch/testing/g +wq!
#sudo apt update
