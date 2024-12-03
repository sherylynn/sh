#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
. $(dirname "$0")/cli.sh
#sudo rurima docker pull -m dockerpull.org -i debian -s ./test
mkdir -p $DEBIAN_DIR
sudo rurima docker pull -m dockerpull.org -i debian -s $DEBIAN_DIR
#卸载
#sudo rurima ruri -U $DEBIAN_DIR
#挂载
#sudo rurima ruri -S -m /sdcard /sdcard -p $DEBIAN_DIR
