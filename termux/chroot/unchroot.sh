#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
. $(dirname "$0")/cli.sh
#. ./cli.sh

# Kill all old prcoesses for umount tmp
sudo killall -9 termux-x11 Xwayland pulseaudio virgl_test_server_android termux-wake-lock virgl_test_server

#
pkill -f com.termux.x11
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11

if [ -f ~/tools/rurima/rurima ]; then
  sudo killall sshd emacs code-server xrdp
  sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR /bin/su - root -c 'vncserver -kill :0 && vncserver -kill :1 && vncserver -kill :2 && killall Xvnc '
  sudo rurima ruri -U $DEBIAN_DIR
elif [ -n "$busybox" ]; then
  unset LD_PRELOAD LD_DEBUG
  stop_dbus
  stop_vnc
  stop_init

  container_umount
#after_umount_fun
fi
