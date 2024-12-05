#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh

#话说链接不带参数会被禁止，感觉不好用
#wps_url=https://wps-linux-personal.wpscdn.cn/wps/download/ep/Linux2019/11719/wps-office_11.1.0.11719_arm64.deb?t=1718868135&k=d1c05d330d0cb18c0bb9616b6402e2c9

case $(arch) in
  amd64) SOFT_ARCH=x64 ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=armv7l ;;
  aarch64)
    wechat_url=https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.deb
    wechat_name=WeChatLinux_arm64.deb
    wps_url=https://github.com/sherylynn/fonts/releases/download/wps/wps-office_11.1.0.11719_arm64.deb
    wps_name="wps-office_11.1.0.11719_arm64.deb"
    ;;
esac
proxy
#不再使用固定版本，使用源自带版本
$(cache_downloader $wps_name $wps_url)
$(cache_downloader $wechat_name $wechat_url)
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

chmod 777 /usr/share/applications/wps-office-wps-aarch64.desktop

sudo dpkg -i $(cache_folder)/$wps_name
#sudo cp /usr/share/applications/wps-office-wps.desktop /usr/share/applications/wps-office-wps-aarch64.desktop
#sudo cp ~/sh/debian/sources.list.mix /etc/apt/sources.list
sudo apt update
#处理官方包图标的依赖
sudo apt install xdg-utils -y
#sudo apt install cn.wps.wps-office-pro -y
sudo apt install -f -y
#为了解决wps打不开缺少依赖
sudo apt install python3-lxml -y

#解决微信的问题
sudo apt install libtiff6 -y
sudo ln -s /usr/lib/aarch64-linux-gnu/libtiff.so.6 /usr/lib/aarch64-linux-gnu/libtiff.so.5
