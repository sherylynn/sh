#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
. $(dirname "$0")/cli.sh

#sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main@' $PREFIX/etc/apt/sources.list
#apt update && apt upgrade -y && apt autoremove -y
#pkg install x11-repo root-repo termux-x11-nightly qemu-system-aarch64-headless -y
pkg install x11-repo root-repo -y
pkg update
pkg install termux-x11-nightly proot-distro -y
pkg install tsu pulseaudio virglrenderer-android -y

#sudo rurima docker pull -m dockerpull.org -i debian -s ./test
mkdir -p $DEBIAN_DIR
sudo rurima docker pull -m dockerpull.org -i debian -s $DEBIAN_DIR
#链接私人文件
sdcard_link
#卸载
sudo rurima ruri -U $DEBIAN_DIR
#挂载
sudo rurima ruri -S -m /sdcard /sdcard -p $DEBIAN_DIR
