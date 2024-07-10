#!/data/data/com.termux/files/usr/bin/bash
#------------------init function----------------
target_host=$1
echo $target_host
apt install getconf tsu pigz rsync -y
. $(dirname "$0")/../../win-get/toolsinit.sh
. ./cli.sh
. ./unchroot.sh

cd ~
if [ ! -d "~/storage/downloads" ]; then
  termux-setup-storage
fi
echo "在外部 termux 中彻底进行备份"
rsync -avz -e 'ssh -p 8022' --progress ${DEBIAN_DIR} root@${target_host}:${DEBIAN_DIR}

#sudo tar -zpcvf ~/storage/downloads/backup_chroot_$(arch).tar.gz --exclude=~/storage --exclude=swap $DEBIAN_DIR
#去掉了文件夹以可以在使用时进行备份
#sudo tar --use-compress-program="pigz -9" -pcvf ~/storage/downloads/backup_chroot_$(arch).tar.gz --exclude=~/storage --exclude=swap --exclude=$DEBIAN_DIR/dev --exclude=$DEBIAN_DIR/proc --exclude=$DEBIAN_DIR/sys --exclude=$DEBIAN_DIR/sdcard --exclude=$DEBIAN_DIR/tmp $DEBIAN_DIR

