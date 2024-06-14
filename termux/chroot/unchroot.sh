#!/bin/sh
. $(dirname "$0")/../../win-git/toolsinit.sh
debian_folder_path="/data/data/com.termux/files/home/Desktop/chrootdebian"
DEBIANPATH=$debian_folder_path
#apatch busybox
busybox=/data/adb/ap/bin/busybox

sudo $busybox umount $DEBIANPATH/dev
sudo $busybox umount $DEBIANPATH/sys
sudo $busybox umount $DEBIANPATH/proc
sudo $busybox umount $DEBIANPATH/dev/pts
sudo $busybox umount $DEBIANPATH/dev/shm
sudo $busybox umount $DEBIANPATH/sdcard
sudo $busybox umount $debian_folder_path/tmp
