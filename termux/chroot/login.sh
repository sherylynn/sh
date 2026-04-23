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
  sdcard_link
  sudo rurima ruri -U $DEBIAN_DIR
  unset LD_PRELOAD LD_DEBUG
  kill_need

  # 自动检查并创建用户（rurima 路径）
  if [ "$LOGIN_USER" = "lynn" ]; then
    if ! sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR id "$LOGIN_USER" >/dev/null 2>&1; then
      echo "[+] 用户 $LOGIN_USER 不存在，正在自动创建..."
      sudo rurima ruri -m /sdcard /sdcard -m /data/data/com.termux/files/usr/tmp /tmp -m /dev /dev -m /dev/pts /dev/pts -m /dev/shm /dev/shm -m /sys /sys -m /proc /proc -p $DEBIAN_DIR /bin/su - root -c '
        user="'"$LOGIN_USER"'"
        uid=1000; while id -u $uid >/dev/null 2>&1; do uid=$((uid+1)); done
        useradd -m -u $uid -s /bin/bash "$user" 2>/dev/null || true
        usermod -aG sudo,video,audio,aid_inet "$user" 2>/dev/null || true
        mkdir -p /etc/sudoers.d
        echo "$user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$user
        chmod 440 /etc/sudoers.d/$user
        echo "$user:123456" | chpasswd
      '
      echo "[✓] 用户 $LOGIN_USER 创建成功 (密码: 123456)"
    fi
  fi

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

  # 自动检查并创建用户
  ensure_chroot_user "$LOGIN_USER" || exit 1

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
