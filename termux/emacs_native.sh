#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh

#中文字体
FONT_NAME_CN=PingFang-Regular.ttf
FONT_URL_CN=https://github.com/ShmilyHTT/PingFang/raw/master/PingFang-Regular.ttf

#英文字体
FONT_NAME_CN=SourceCodePro-Regular.ttf
FONT_URL_CN=https://github.com/adobe-fonts/source-code-pro/raw/release/TTF/SourceCodePro-Regular.ttf

#路径设置
TERMUX_HOME=/data/data/com.termux/files/home
TERMUX_FONT_DIR=$TERMUX_HOME/.termux
NATIVE_EMACS_HOME=/data/data/org.gnu.emacs/files
TERMUX_EMACS_FONT_DIR=$TERMUX_HOME/.local/share/fonts
CACHE_HOME=$HOME/
#映射后的native地址
NATIVE_EMACS_FONT_DIR=$TERMUX_HOME/fonts

#安装依赖包
apt install -y libvterm build-essential wget
#干掉默认的emacs的HOME，链接termux的HOME
rm -rf $NATIVE_EMACS_HOME
ln -s $TERMUX_HOME $NATIVE_EMACS_HOME
#链接termux下emacsx的fonts
rm -rf $NATIVE_EMACS_FONT_DIR
mkdir -p $TERMUX_EMACS_FONT_DIR
ln -s $TERMUX_EMACS_FONT_DIR $NATIVE_EMACS_FONT_DIR
rm -rf $TERMUX_EMACS_FONT_DIR/font.ttf
#设置termux的字体
rm  $TERMUX_FONT_DIR/font.ttf
ln -s /system/fonts/DroidSansMono.ttf  $TERMUX_FONT_DIR/font.ttf
#设置emacs的字体
ln -s /system/fonts/DroidSansMono.ttf $NATIVE_EMACS_FONT_DIR/font.ttf

#下载中文字体
$(cache_downloader $FONT_NAME_CN $FONT_URL_CN)
rm $NATIVE_EMACS_FONT_DIR/$FONT_NAME_CN
ln -s $(cache_folder)/$FONT_NAME_CN $NATIVE_EMACS_FONT_DIR/$FONT_NAME_CN

#下载英文字体
$(cache_downloader $FONT_NAME_EN $FONT_URL_EN)
rm $NATIVE_EMACS_FONT_DIR/$FONT_NAME_EN
ln -s $(cache_folder)/$FONT_NAME_EN $NATIVE_EMACS_FONT_DIR/$FONT_NAME_EN
