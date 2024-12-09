#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh

#话说链接不带参数会被禁止，感觉不好用
#wps_url=https://wps-linux-personal.wpscdn.cn/wps/download/ep/Linux2019/11719/wps-office_11.1.0.11719_arm64.deb?t=1718868135&k=d1c05d330d0cb18c0bb9616b6402e2c9

case $(arch) in
  amd64) SOFT_ARCH=x64 ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=armv7l ;;
  aarch64)
    todesk_url=https://dl.todesk.com/linux/todesk-v4.7.2.0-arm64.deb
    todesk_name=todesk-v4.7.2.0-arm64.deb
    ;;
esac

#不再使用固定版本，使用源自带版本
$(cache_downloader $todesk_name $todesk_url)

#解决todesk的问题
sudo apt-get install libappindicator3-1
sudo dpkg -i $(cache_folder)/$todesk_name
