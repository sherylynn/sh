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
#testing
#sudo test ! -e $DEBIAN_DIR/bin/dpkg && sudo rurima docker pull -m dockerpull.org -i debian -t testing -s $DEBIAN_DIR
#bookworm
sudo test ! -e $DEBIAN_DIR/bin/dpkg && sudo rurima docker pull -m dockerpull.org -i debian -t bookworm -s $DEBIAN_DIR
#链接私人文件
sdcard_link
#卸载
sudo rurima ruri -U $DEBIAN_DIR

unset LD_PRELOAD LD_DEBUG
#testing
#sudo cp ~/sh/debian/sources.list.tuna $DEBIAN_DIR/etc/apt/sources.list
#1
sudo cp ~/sh/debian/debian.sources.tuna $DEBIAN_DIR/etc/apt/sources.list.d/debian.sources
#2
#docker里的sources.list压根没东西 ,换了一个位置
#/data/data/com.termux/files/home/sh/debian/debian_mirror.sh $DEBIAN_DIR/etc/apt/sources.list.d/debian.sources

sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR /bin/su - root -c 'echo "nameserver 114.114.114.114" > /etc/resolv.conf; \
    echo "127.0.0.1 localhost" > /etc/hosts; \
    groupadd -g 3003 aid_inet; \
    groupadd -g 3004 aid_net_raw; \
    groupadd -g 1003 aid_graphics; \
    usermod -g 3003 -G 3003,3004 -a _apt; \
    usermod -G 3003 -a root; \
    apt update; \
    apt install git vim wget curl sudo -y; \
    git clone --depth 1 http://github.com/sherylynn/sh  ~/sh; \
    git -C ~/sh pull; \
test -f ~/tools/rc/allToolsrc & zsh ~/tools/rc/allToolsrc; \
    ~/sh/debian/debian_mirror.sh; \
    apt update; \
    apt upgrade -y; \
    apt autoremove -y; \
    apt install net-tools zsh -y; \
    echo "Debian chroot environment configured"'

sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR /bin/su - root -c 'test -f ~/tools/rc/allToolsrc & zsh ~/tools/rc/allToolsrc & zsh /root/sh/win-git/server_configure.sh'
