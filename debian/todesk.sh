#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh

NAME=todesk
SOFT_VERSION=v4.7.2.0

case $(arch) in
  amd64)
    SOFT_ARCH=amd64
    ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=armv7l ;;
  aarch64)
    SOFT_ARCH=arm64
    ;;
esac

SOFT_URL=https://dl.todesk.com/linux/${NAME}-${SOFT_VERSION}-${SOFT_ARCH}.deb
SOFT_NAME=${NAME}-${SOFT_VERSION}-${SOFT_ARCH}.deb
#不再使用固定版本，使用源自带版本
$(cache_downloader $SOFT_NAME $SOFT_URL)

#解决todesk的问题
sudo apt-get install libappindicator3-1
sudo dpkg -i $(cache_folder)/$SOFT_NAME
