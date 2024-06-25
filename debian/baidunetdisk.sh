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
#sudo dpkg -i  $(cache_folder)/$lib_name 
sudo apt install com.baidu.baidunetdisk -y
sudo apt install -f -y

#还需要zink作为显卡才能跑起来

if [[ $(whoami) == "root" ]]; then
    #如果是root则关闭sandbox
tee /usr/share/applications/baidunetdisk.desktop <<-'EOF'
[Desktop Entry]
Categories=Network;
Comment=Baidu Netdisk
Comment[zh_CN]=百度网盘
Comment[zh_TW]=百度网盘
Exec="/opt/apps/com.baidu.baidunetdisk/files/baidunetdisk/baidunetdisk" --no-sandbox %U
Icon=/opt/apps/com.baidu.baidunetdisk/entries/icons/hicolor/scalable/apps/baidunetdisk.svg
MimeType=x-scheme-handler/baiduyunguanjia;
Name=Baidu Netdisk
Name[zh_CN]=百度网盘
Name[zh_TW]=百度网盘
StartupWMClass=baidunetdisk
Terminal=false
Type=Application
X-Deepin-Vendor=user-custom
EOF
fi

chmod 777 /usr/share/applications/baidunetdisk.desktop 
