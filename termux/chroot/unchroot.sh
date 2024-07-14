#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
. $(dirname "$0")/cli.sh
#. ./cli.sh

# Kill all old prcoesses for umount tmp
sudo killall -9 termux-x11 Xwayland pulseaudio virgl_test_server_android termux-wake-lock

unset LD_PRELOAD LD_DEBUG
stop_dbus
stop_vnc
stop_init

container_umount
#after_umount_fun
