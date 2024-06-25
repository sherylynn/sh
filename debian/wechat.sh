#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh

mirrors=http://mirrors.ustc.edu.cn/debian/pool/main/o/openssl/
case $(arch) in 
  amd64) SOFT_ARCH=amd64;;
  386) SOFT_ARCH=x86;;
  armhf) SOFT_ARCH=armv7l;;
  aarch64)
    SOFT_ARCH=arm64
    ;;
esac

lib_name=libssl1.1_1.1.1w-0+deb11u1_$SOFT_ARCH.deb
lib_url=$mirrors$lib_name
proxy
$(cache_downloader $lib_name $lib_url)
#为了解决wechat缺少的依赖
sudo dpkg -i  $(cache_folder)/$lib_name 
sudo apt install com.tencent.wechat -y
sudo apt install -f -y

sudo cp /opt/apps/com.tencent.wechat/entries/applications/com.tencent.wechat.desktop ~/Desktop/
