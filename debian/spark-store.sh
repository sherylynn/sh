#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
mirrors=https://gitee.com/spark-store-project/spark-store/releases/download/4.2.13.1/
case $(arch) in 
  amd64) SOFT_ARCH=amd64;;
  386) SOFT_ARCH=x86;;
  armhf) SOFT_ARCH=armv7l;;
  aarch64)
    SOFT_ARCH=arm64
    ;;
esac

#直接安装商店真的很卡，不如安装终端版本，连图标都不用费心了
#lib_name=spark-store_4.2.13.1_$SOFT_ARCH.deb
#还方便自动化, 商店版本chroot时候的gpu用virgl有问题，只能用pipe来算
lib_name=spark-store-console_4.2.12_all.deb
lib_url=$mirrors$lib_name
proxy
$(cache_downloader $lib_name $lib_url)
#为了解决wechat缺少的依赖
sudo apt install -y $(cache_folder)/$lib_name 

#还需要zink作为显卡才能跑起来

if [[ $(whoami) == "root" ]]; then
    #如果是root则关闭sandbox
tee /usr/share/applications/spark-store.desktop <<-'EOF'
[Desktop Entry]
Encoding=UTF-8
Type=Application
Categories=System;
Exec=spark-store %u --no-sandbox
Icon=spark-store
Name=Spark Store
Name[zh_CN]=星火应用商店
Keywords=appstore;
Terminal=false
StartupNotify=true
StartupWMClass=spark-store
MimeType=x-scheme-handler/spk
EOF
fi

chmod 777 /usr/share/applications/spark-store.desktop
