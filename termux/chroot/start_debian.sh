#!/bin/sh

#apatch busybox
busybox=/data/adb/ap/bin/busybox

#Path of DEBIAN rootfs
debian_folder_path="/data/data/com.termux/files/home/Desktop/chrootdebian"
DEBIANPATH=$debian_folder_path

# Fix setuid issue
sudo $busybox mount -o remount,dev,suid /data

sudo $busybox mount --bind /dev $DEBIANPATH/dev
sudo $busybox mount --bind /sys $DEBIANPATH/sys
sudo $busybox mount --bind /proc $DEBIANPATH/proc
sudo $busybox mount -t devpts devpts $DEBIANPATH/dev/pts

# /dev/shm for Electron apps
sudo mkdir -p $DEBIANPATH/dev/shm
sudo $busybox mount -t tmpfs -o size=256M tmpfs $DEBIANPATH/dev/shm

# Mount sdcard
sudo mkdir -p $DEBIANPATH/sdcard
sudo $busybox mount --bind /sdcard $DEBIANPATH/sdcard

# chroot into DEBIAN
#sudo $busybox chroot $DEBIANPATH /bin/su - root
#sudo $busybox chroot $DEBIANPATH /bin/su - root -c 'export XDG_RUNTIME_DIR=${TMPDIR} && export PULSE_SERVER=tcp:127.0.0.1:4713 && sudo service dbus start && su - lynn -c "env DISPLAY=:0 startxfce4"'
#for fcitx5
sudo $busybox chroot $DEBIANPATH /bin/su - lynn -c 'export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 && \
export GTK_IM_MODULE="fcitx" && \
export QT_IM_MODULE="fcitx" && \
export XMODIFIERS="@im=fcitx" && \
#fcitx5 && \
dbus-launch --exit-with-session startxfce4'
