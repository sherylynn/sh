#!/data/data/com.termux/files/usr/bin/bash

. $(dirname "$0")/cli.sh

# 用户支持：bash noVNC.sh [用户名]
CHROOT_USER="${1:-${CHROOT_USER:-root}}"
if [ "$CHROOT_USER" = "root" ]; then
  CHROOT_HOME="/root"
else
  CHROOT_HOME="/home/$CHROOT_USER"
fi

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
if [ -f "/sdcard/Download/使用虚拟显卡.txt" ]; then
  echo "检测到强制使用虚拟显卡文件，启动virgl_test_server_android"
  virgl_test_server_android &
elif lscpu | grep -q "Oryon"; then
  echo "Oryon CPU detected, skipping virgl_test_server_android"
else
  virgl_test_server_android &
fi

# Determine driver environment variables
if [ -f "/sdcard/Download/使用虚拟显卡.txt" ] || ! lscpu | grep -q "Oryon"; then
  DRIVER_ENV='export GALLIUM_DRIVER=virpipe && export MESA_GL_VERSION_OVERRIDE=4.0 &&'
else
  DRIVER_ENV='export MESA_LOADER_DRIVER_OVERRIDE=kgsl && export TU_DEBUG=noconform &&'
fi

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

  sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR /bin/su - $CHROOT_USER -c 'export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 && \
export GTK_IM_MODULE="fcitx" && \
export QT_IM_MODULE="fcitx" && \
export XMODIFIERS="@im=fcitx" && \
#fcitx5 && \
'"$DRIVER_ENV"' \
cd ~ && \
chmod 1777 /dev/shm && \
sh ~/sh/win-git/server_noVNC.sh'
elif [ -n "$busybox" ]; then
  # Execute chroot script
  container_mounted || container_mount
  #before_mount_fun

  termux_data_path=/data/data/com.termux/files/home
  termux_gitcredentials=$termux_data_path/.git-credentials
  termux_gitconfig=$termux_data_path/.gitconfig

  test -f $termux_gitconfig && sudo cp $termux_gitconfig $CHROOT_DIR$CHROOT_HOME/
  test -f $termux_gitcredentials && sudo cp $termux_gitcredentials $CHROOT_DIR$CHROOT_HOME/

  unset LD_PRELOAD LD_DEBUG
  start_dbus
  #start_vnc
  sudo $busybox chroot $CHROOT_DIR /bin/su - $CHROOT_USER -c 'export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 && \
export GTK_IM_MODULE="fcitx" && \
export QT_IM_MODULE="fcitx" && \
export XMODIFIERS="@im=fcitx" && \
#fcitx5 && \
'"$DRIVER_ENV"' \
cd ~ && \
sh ~/sh/win-git/server_noVNC.sh'
#dbus-launch --exit-with-session zsh ~/sh/win-git/server_noVNC.sh'

fi