#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh

#中文字体
#FONT_NAME_CN=PingFang-Regular.ttf
#FONT_URL_CN=https://github.com/ShmilyHTT/PingFang/raw/master/PingFang-Regular.ttf
FONT_NAME_CN=sarasa-term-sc-nerd-regular.ttf
FONT_URL_CN=https://github.com/sherylynn/fonts/raw/main/sarasa-term-sc-nerd-regular.ttf

#英文字体
FONT_NAME_EN=SourceCodePro-Regular.ttf
FONT_URL_EN=https://github.com/adobe-fonts/source-code-pro/raw/release/TTF/SourceCodePro-Regular.ttf

#路径设置
TERMUX_HOME=/data/data/com.termux/files/home
TERMUX_FONT_DIR=$TERMUX_HOME/.termux
NATIVE_EMACS_HOME=/data/data/org.gnu.emacs/files
TERMUX_EMACS_FONT_DIR=$TERMUX_HOME/.local/share/fonts
CACHE_HOME=$HOME/
#映射后的 native 地址
NATIVE_EMACS_FONT_DIR=$TERMUX_HOME/fonts

#安装依赖包
apt install -y libvterm build-essential wget tsu
apt install -y librime
#干掉默认的 emacs 的 HOME，链接 termux 的 HOME
#新版本的emacs好像签名又不一样了，读不了文件了
rm -rf $NATIVE_EMACS_HOME
ln -s $TERMUX_HOME $NATIVE_EMACS_HOME
#链接 termux 下 emacsx 的 fonts
rm -rf $NATIVE_EMACS_FONT_DIR
mkdir -p $TERMUX_EMACS_FONT_DIR
ln -s $TERMUX_EMACS_FONT_DIR $NATIVE_EMACS_FONT_DIR
rm -rf $TERMUX_EMACS_FONT_DIR/font.ttf

#下载中文字体
$(cache_downloader $FONT_NAME_CN $FONT_URL_CN)
rm $NATIVE_EMACS_FONT_DIR/$FONT_NAME_CN
ln -s $(cache_folder)/$FONT_NAME_CN $NATIVE_EMACS_FONT_DIR/$FONT_NAME_CN

#下载英文字体
$(cache_downloader $FONT_NAME_EN $FONT_URL_EN)
rm $NATIVE_EMACS_FONT_DIR/$FONT_NAME_EN
ln -s $(cache_folder)/$FONT_NAME_EN $NATIVE_EMACS_FONT_DIR/$FONT_NAME_EN

#设置 termux 的字体 [默认安卓自带的]
rm  $TERMUX_FONT_DIR/font.ttf
#ln -s /system/fonts/DroidSansMono.ttf  $TERMUX_FONT_DIR/font.ttf
#用更纱黑体，中英文都对齐
ln -s $(cache_folder)/$FONT_NAME_CN  $TERMUX_FONT_DIR/font.ttf

#设置 emacs 的字体 [默认安卓自带的]
#ln -s /system/fonts/DroidSansMono.ttf $NATIVE_EMACS_FONT_DIR/font.ttf
#用更纱黑体，中英文都对齐
ln -s $(cache_folder)/$FONT_NAME_CN  $NATIVE_EMACS_FONT_DIR/font.ttf
