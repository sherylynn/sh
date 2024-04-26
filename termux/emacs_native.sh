#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
FONT_NAME=PingFang-Regular.ttf
FONT_URL=https://github.com/ShmilyHTT/PingFang/raw/master/PingFang-Regular.ttf

#干掉默认的emacs的HOME，链接termux的HOME
rm -rf /data/data/org.gnu.emacs/files
ln -s /data/data/com.termux/files/home /data/data/org.gnu.emacs/files
#链接termux下emacsx的fonts
rm -rf /data/data/com.termux/files/home/fonts
mkdir -p /data/data/com.termux/files/home/.local/share/fonts
ln -s /data/data/com.termux/files/home/.local/share/fonts /data/data/com.termux/files/home/fonts
rm -rf /data/data/com.termux/files/home/fonts/font.ttf
rm  /data/data/com.termux/files/home/.termux/font.ttf
#ln -s /system/fonts/SourceSansPro-Regular.ttf /data/data/com.termux/files/home/.termux/font.ttf
#设置termux的字体
ln -s /system/fonts/DroidSansMono.ttf /data/data/com.termux/files/home/.termux/font.ttf
#设置emacs的字体
ln -s /system/fonts/DroidSansMono.ttf /data/data/com.termux/files/home/fonts/font.ttf
#ln -s /system/fonts/SourceSansPro-Regular.ttf /data/data/com.termux/files/home/fonts/font.ttf
#下载苹方字体
$(cache_downloader $FONT_NAME $FONT_URL)
rm /data/data/com.termux/files/home/fonts/PingFang-Regular.ttf 
ln -s /data/data/com.termux/files/home/tools/cache/PingFang-Regular.ttf /data/data/com.termux/files/home/fonts/PingFang-Regular.ttf 
