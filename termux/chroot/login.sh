#!/data/data/com.termux/files/usr/bin/bash

# 支持指定用户登录：bash login.sh [用户名]
# 默认: root，可通过 --user/-u 或第一个参数指定

# 解析参数
LOGIN_USER="${CHROOT_USER:-root}"
if [ -n "$1" ] && [ "$1" != "--user" ] && [ "$1" != "-u" ]; then
  LOGIN_USER="$1"
elif [ "$2" ]; then
  LOGIN_USER="$2"
fi

. $(dirname "$0")/cli.sh
# Kill all old prcoesses
sudo killall -9 termux-x11 Xwayland pulseaudio virgl_test_server_android termux-wake-lock

clean_tmp
#XDG_RUNTIME_DIR=${TMPDIR} sleep 3

# 确定用户home目录
if [ "$LOGIN_USER" = "root" ]; then
  LOGIN_HOME="/root"
else
  LOGIN_HOME="/home/$LOGIN_USER"
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
  kill_need

  sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR /bin/su - $LOGIN_USER -c 'export PULSE_SERVER=127.0.0.1 && \
export GTK_IM_MODULE="fcitx" && \
export QT_IM_MODULE="fcitx" && \
export XMODIFIERS="@im=fcitx" && \
#fcitx5 && \
export GALLIUM_DRIVER=virpipe && \
export MESA_GL_VERSION_OVERRIDE=4.0 && \
source ~/tools/rc/allToolsrc
zsh'

elif [ -n "$busybox" ]; then
  # Execute chroot script
  container_mounted || container_mount
  #before_mount_fun

  termux_data_path=/data/data/com.termux/files/home
  termux_gitcredentials=$termux_data_path/.git-credentials
  termux_gitconfig=$termux_data_path/.gitconfig

  # 复制 git 配置到用户 home 目录
  test -f $termux_gitconfig && sudo cp $termux_gitconfig $CHROOT_DIR$LOGIN_HOME/
  test -f $termux_gitcredentials && sudo cp $termux_gitcredentials $CHROOT_DIR$LOGIN_HOME/

  unset LD_PRELOAD LD_DEBUG

  start_dbus
  sudo $busybox chroot $CHROOT_DIR /bin/su - $LOGIN_USER -c 'export PULSE_SERVER=127.0.0.1 && \
export GTK_IM_MODULE="fcitx" && \
export QT_IM_MODULE="fcitx" && \
export XMODIFIERS="@im=fcitx" && \
#fcitx5 && \
export GALLIUM_DRIVER=virpipe && \
export MESA_GL_VERSION_OVERRIDE=4.0 && \
source ~/tools/rc/allToolsrc && \
zsh '

fi
