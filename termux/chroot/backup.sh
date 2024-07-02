#!/data/data/com.termux/files/usr/bin/bash
#------------------init function----------------
apt install getconf tsu pigz -y
. $(dirname "$0")/../../win-get/toolsinit.sh
. ./cli.sh
. ./unchroot.sh

cd ~
if [ ! -d "~/storage/downloads"]; then
  termux-setup-storage
fi

echo "在外部termux中彻底进行备份"

#sudo tar -zpcvf ~/storage/downloads/backup_chroot_$(arch).tar.gz --exclude=~/storage --exclude=swap $DEBIAN_DIR
#去掉了文件夹以可以在使用时进行备份
sudo tar --use-compress-program="pigz -9" -pcvf ~/storage/downloads/backup_chroot_$(arch).tar.gz --exclude=~/storage --exclude=swap --exclude=$DEBIAN_DIR/dev --exclude=$DEBIAN_DIR/proc --exclude=$DEBIAN_DIR/sys --exclude=$DEBIAN_DIR/sdcard --exclude=$DEBIAN_DIR/tmp $DEBIAN_DIR

