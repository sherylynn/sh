#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
mirrors=https://gitee.com/spark-store-project/spark-store/releases/download/4.2.13.1/
NAME=sparkSTORE
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
#SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)

case $(arch) in
  amd64) SOFT_ARCH=amd64 ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=armv7l ;;
  aarch64)
    SOFT_ARCH=arm64
    ;;
esac

#直接安装商店真的很卡，不如安装终端版本，连图标都不用费心了
#lib_name=spark-store_4.2.13.1_$SOFT_ARCH.deb
#还方便自动化, 商店版本chroot时候的gpu用virgl有问题，只能用pipe来算
lib_name=spark-store-console_4.2.13_all.deb
lib_url=$mirrors$lib_name
#proxy
$(cache_downloader $lib_name $lib_url)
#为了解决wechat缺少的依赖
sudo apt install -y $(cache_folder)/$lib_name
#for wps depends
sudo apt install xdg-utils -y
#为了解决wps打不开缺少依赖
sudo apt install python3-lxml -y
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

case $(arch) in
  amd64) SOFT_ARCH=amd64 ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=armv7l ;;
  aarch64)
    tee /usr/share/applications/wps-office-wps-aarch64.desktop <<-'EOF'
[Desktop Entry]
Comment=Use WPS Writer to edit articles and reports.
Comment[zh_CN]=使用 WPS 文字编写报告，排版文章
Exec=/usr/bin/wps %U
GenericName=WPS Writer
GenericName[zh_CN]=WPS 文字
MimeType=application/wps-office.wps;application/wps-office.wpt;application/wps-office.wpso;application/wps-office.wpss;application/wps-office.doc;application/wps-office.dot;application/vnd.ms-word;application/msword;application/x-msword;application/msword-template;application/wps-office.docx;application/wps-office.dotx;application/rtf;application/vnd.ms-word.document.macroEnabled.12;application/vnd.openxmlformats-officedocument.wordprocessingml.document;x-scheme-handler/ksoqing;x-scheme-handler/ksowps;x-scheme-handler/ksowpp;x-scheme-handler/ksoet;x-scheme-handler/ksowpscloudsvr;x-scheme-handler/ksowebstartupwps;x-scheme-handler/ksowebstartupet;x-scheme-handler/ksowebstartupwpp;application/wps-office.uot;
Name=WPS Writer
Name[zh_CN]=WPS 文字
StartupNotify=false
Terminal=false
Type=Application
Categories=Office;WordProcessor;Qt;
X-DBUS-ServiceName=
X-DBUS-StartupType=
X-KDE-SubstituteUID=false
X-KDE-Username=
Icon=wps-office2019-wpsmain
InitialPreference=3
StartupWMClass=wps
EOF
    ;;
esac

#echo "alias bwrap='echo'" >${TOOLSRC}
