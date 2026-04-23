#!/data/data/com.termux/files/usr/bin/bash

. $(dirname "$0")/cli.sh
#. ./cli.sh

# 用户支持：bash x11.sh [用户名]
CHROOT_USER="${1:-${CHROOT_USER:-root}}"
if [ "$CHROOT_USER" = "root" ]; then
  CHROOT_HOME="/root"
else
  CHROOT_HOME="/home/$CHROOT_USER"
fi

# Kill all old prcoesses
#sudo killall -9 termux-x11 Xwayland pulseaudio virgl_test_server_android termux-wake-lock
. $(dirname "$0")/unchroot.sh

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
  sdcard_link
  sudo rurima ruri -U $DEBIAN_DIR
  unset LD_PRELOAD LD_DEBUG

  # 自动检查并创建用户（rurima 路径）
  if [ "$CHROOT_USER" = "lynn" ]; then
    if ! sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR grep -q "^lynn:" /etc/passwd 2>/dev/null; then
      echo "[+] 用户 $CHROOT_USER 不存在，正在自动创建..."
      sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR /bin/su - root -c '
        user="'"$CHROOT_USER"'"
        # 清理残留并创建用户
        if id lynn >/dev/null 2>&1; then
          userdel -r lynn 2>/dev/null || true
        fi
        rm -rf /home/lynn
        useradd -m -u 1000 -s /bin/bash lynn
        usermod -aG sudo,video,audio,aid_inet lynn
        mkdir -p /etc/sudoers.d
        echo "lynn ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/lynn
        chmod 440 /etc/sudoers.d/lynn
        grep -q "^#includedir /etc/sudoers.d" /etc/sudoers 2>/dev/null || echo "#includedir /etc/sudoers.d" >> /etc/sudoers
        grep -q "^%sudo" /etc/sudoers 2>/dev/null || echo "%sudo ALL=(ALL:ALL) ALL" >> /etc/sudoers
        echo "lynn:123456" | chpasswd
      '
      echo "[✓] 用户 lynn 已就绪 (uid=1000)"
    fi
  fi

  sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR /bin/su - $CHROOT_USER -c 'export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 && \
    export GTK_IM_MODULE="fcitx" &&
    export QT_IM_MODULE="fcitx" &&
    export XMODIFIERS="@im=fcitx" &&
    '"$DRIVER_ENV"' \
    #fcitx5 & 
    source ~/tools/rc/allToolsrc
  dbus-launch --exit-with-session startxfce4'
elif [ -n "$busybox" ]; then
  # Execute chroot script
  container_mounted || container_mount

  # 自动检查并创建用户
  ensure_chroot_user "$CHROOT_USER" || exit 1

  termux_data_path=/data/data/com.termux/files/home
  termux_gitcredentials=$termux_data_path/.git-credentials
  termux_gitconfig=$termux_data_path/.gitconfig

  test -f $termux_gitconfig && sudo cp $termux_gitconfig $CHROOT_DIR$CHROOT_HOME/
  test -f $termux_gitcredentials && sudo cp $termux_gitcredentials $CHROOT_DIR$CHROOT_HOME/

  unset LD_PRELOAD LD_DEBUG
  sudo $busybox chroot $CHROOT_DIR /bin/su - $CHROOT_USER -c 'export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 &&
    export GTK_IM_MODULE="fcitx" &&
    export QT_IM_MODULE="fcitx" &&
    export XMODIFIERS="@im=fcitx" &&
    '"$DRIVER_ENV"' \
    zsh ~/tools/rc/allToolsrc
  dbus-launch --exit-with-session startxfce4'
#startxfce4'
#vncserver -kill :0 && \
#rm -rf /tmp/.X* && \
fi