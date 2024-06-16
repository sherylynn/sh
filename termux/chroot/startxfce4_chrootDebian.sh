#!/data/data/com.termux/files/usr/bin/bash

. ./start_debian.sh
# Kill all old prcoesses
sudo killall -9 termux-x11 Xwayland pulseaudio virgl_test_server_android termux-wake-lock

## Start Termux X11
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity

#sudo $busybox mount --bind $PREFIX/tmp $CHROOT_DIR/tmp

XDG_RUNTIME_DIR=${TMPDIR} termux-x11 :0 -ac &

sleep 3

# Start Pulse Audio of Termux
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1

# Start virgl server
virgl_test_server_android &

# Execute chroot script
#container_mounted || container_mount
before_mount_fun

sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 && \
export GTK_IM_MODULE="fcitx" && \
export QT_IM_MODULE="fcitx" && \
export XMODIFIERS="@im=fcitx" && \
#fcitx5 && \
dbus-launch --exit-with-session startxfce4'
