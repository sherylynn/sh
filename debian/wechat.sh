#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh

NAME=WeChatLinux

case $(arch) in
  amd64)
    SOFT_ARCH=x86_64
    ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=armv7l ;;
  aarch64)
    SOFT_ARCH=arm64
    ;;
esac

SOFT_URL=https://dldir1v6.qq.com/weixin/Universal/Linux/${NAME}_${SOFT_ARCH}.deb
#qq download url
#https://dldir1.qq.com/qqfile/qq/QQNT/Linux/QQ_3.2.15_250110_arm64_01.deb
SOFT_NAME=${NAME}_${SOFT_ARCH}.deb

#不再使用固定版本，使用源自带版本
$(cache_downloader $SOFT_NAME $SOFT_URL)
#解决微信的问题
sudo dpkg -i $(cache_folder)/$SOFT_NAME
sudo apt install libtiff6 -y
sudo ln -s /usr/lib/aarch64-linux-gnu/libtiff.so.6 /usr/lib/aarch64-linux-gnu/libtiff.so.5
