#!/data/data/com.termux/files/usr/bin/bash

. $(dirname "$0")/cli.sh
#. ./cli.sh
# Kill all old prcoesses
sudo killall -9 termux-x11 Xwayland pulseaudio virgl_test_server_android termux-wake-lock

## Start Termux X11
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity

clean_tmp
#sudo $busybox mount --bind $PREFIX/tmp $CHROOT_DIR/tmp

XDG_RUNTIME_DIR=${TMPDIR} termux-x11 :0 -ac &

sleep 3

# Start Pulse Audio of Termux
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1

# Start virgl server
virgl_test_server_android &

if [ -f ~/tools/rurima/rurima ]; then

  sudo mount -o remount,dev,suid /data
  #sudo mount -o remount,suid /data
  #挂载sdcard隐私文件
  sdcard_link
  #解除挂载
  sudo rurima ruri -U $DEBIAN_DIR
  #挂载
  #sudo $busybox mount --bind $PREFIX/tmp $CHROOT_DIR/tmp
  unset LD_PRELOAD LD_DEBUG
  #sudo rurima ruri -S -m /data/data/com.termux/files/usr/tmp /tmp -m /sdcard /sdcard -p $DEBIAN_DIR /bin/su - root -c 'export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 &&
  sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR /bin/su - root -c 'export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 && \
    export GTK_IM_MODULE="fcitx" &&
    export QT_IM_MODULE="fcitx" &&
    export XMODIFIERS="@im=fcitx" &&
    #fcitx5 && \
    export GALLIUM_DRIVER=virpipe &&
    export MESA_GL_VERSION_OVERRIDE=4.0 &&
    zsh ~/tools/rc/allToolsrc
  dbus-launch --exit-with-session startxfce4'
elif [ -n "$busybox" ]; then
  # Execute chroot script
  container_mounted || container_mount
  #before_mount_fun

  termux_data_path=/data/data/com.termux/files/home
  termux_gitcredentials=$termux_data_path/.git-credentials
  termux_gitconfig=$termux_data_path/.gitconfig

  test -f $termux_gitconfig && sudo cp $termux_gitconfig $CHROOT_DIR/root/
  test -f $termux_gitcredentials && sudo cp $termux_gitcredentials $CHROOT_DIR/root/

  unset LD_PRELOAD LD_DEBUG
  sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 &&
    export GTK_IM_MODULE="fcitx" &&
    export QT_IM_MODULE="fcitx" &&
    export XMODIFIERS="@im=fcitx" &&
    #fcitx5 && \
    export GALLIUM_DRIVER=virpipe &&
    export MESA_GL_VERSION_OVERRIDE=4.0 &&
    zsh ~/tools/rc/allToolsrc
  dbus-launch --exit-with-session startxfce4'
#startxfce4'
#vncserver -kill :0 && \
#rm -rf /tmp/.X* && \
fi
