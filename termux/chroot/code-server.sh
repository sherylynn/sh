#!/data/data/com.termux/files/usr/bin/bash

. $(dirname "$0")/cli.sh

# 用户支持：bash code-server.sh [用户名]
CHROOT_USER="${1:-${CHROOT_USER:-root}}"
if [ "$CHROOT_USER" = "root" ]; then
  CHROOT_HOME="/root"
else
  CHROOT_HOME="/home/$CHROOT_USER"
fi

# Kill all old prcoesses
sudo killall -9 termux-x11 Xwayland pulseaudio virgl_test_server_android termux-wake-lock

clean_tmp
#XDG_RUNTIME_DIR=${TMPDIR} sleep 3

if [ -f ~/tools/rurima/rurima ]; then
  sudo mount -o remount,dev,suid /data
  sdcard_link
  sudo rurima ruri -U $DEBIAN_DIR
  unset LD_PRELOAD LD_DEBUG
  kill_need

  # 自动检查并创建用户（rurima 路径）
  if [ "$CHROOT_USER" = "lynn" ]; then
    if ! sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR grep -q "^lynn:" /etc/passwd 2>/dev/null; then
      echo "[+] 用户 $CHROOT_USER 不存在，正在自动创建..."
      sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR /bin/su - root -c '
        user="'"$CHROOT_USER"'"
        # 检查用户是否已存在
        if ! grep -q "^lynn:" /etc/passwd 2>/dev/null; then
          useradd -m -u 1000 -s /bin/bash lynn
          usermod -aG sudo,video,audio,aid_inet lynn
          mkdir -p /etc/sudoers.d
          echo "lynn ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/lynn
          chmod 440 /etc/sudoers.d/lynn
          echo "lynn:123456" | chpasswd
        fi
      '
      echo "[✓] 用户 lynn 已就绪 (uid=1000)"
    fi
  fi

  sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR /bin/su - $CHROOT_USER -c 'export PULSE_SERVER=127.0.0.1 && \
export GTK_IM_MODULE="fcitx" && \
export QT_IM_MODULE="fcitx" && \
export XMODIFIERS="@im=fcitx" && \
#fcitx5 && \
export GALLIUM_DRIVER=virpipe && \
export MESA_GL_VERSION_OVERRIDE=4.0 && \
source ~/tools/rc/allToolsrc && \
zsh ~/sh/win-git/server_code-server.sh'

  #sudo rurima ruri -S -m /sdcard /sdcard -p $DEBIAN_DIR /bin/su - root
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
  #sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 && \

  start_dbus
  sudo $busybox chroot $CHROOT_DIR /bin/su - $CHROOT_USER -c 'export PULSE_SERVER=127.0.0.1 && \
export GTK_IM_MODULE="fcitx" && \
export QT_IM_MODULE="fcitx" && \
export XMODIFIERS="@im=fcitx" && \
#fcitx5 && \
export GALLIUM_DRIVER=virpipe && \
export MESA_GL_VERSION_OVERRIDE=4.0 && \
#zsh ~/tools/rc/allToolsrc && \
zsh ~/sh/win-git/ssh.sh'
#dbus-launch --exit-with-session startxfce4'
#startxfce4'
#vncserver -kill :0 && \
#rm -rf /tmp/.X* && \

fi
