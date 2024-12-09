#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh

case $(arch) in
  amd64) SOFT_ARCH=x64 ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=armv7l ;;
  aarch64)
    wechat_url=https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.deb
    wechat_name=WeChatLinux_arm64.deb
    ;;
esac

#不再使用固定版本，使用源自带版本
$(cache_downloader $wechat_name $wechat_url)

#解决微信的问题
sudo dpkg -i $(cache_folder)/$wechat_name
sudo apt install libtiff6 -y
sudo ln -s /usr/lib/aarch64-linux-gnu/libtiff.so.6 /usr/lib/aarch64-linux-gnu/libtiff.so.5
