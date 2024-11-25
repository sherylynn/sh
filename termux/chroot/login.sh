#!/data/data/com.termux/files/usr/bin/bash

. ./cli.sh
# Kill all old prcoesses
sudo killall -9 termux-x11 Xwayland pulseaudio virgl_test_server_android termux-wake-lock

if [ -e "$busybox" ]; then
  # Execute chroot script
  container_mounted || container_mount
  #before_mount_fun

  termux_data_path=/data/data/com.termux/files/home
  termux_gitcredentials=$termux_data_path/.git-credentials
  termux_gitconfig=$termux_data_path/.gitconfig

  test -f $termux_gitconfig && sudo cp $termux_gitconfig $CHROOT_DIR/root/
  test -f $termux_gitcredentials && sudo cp $termux_gitcredentials $CHROOT_DIR/root/

  unset LD_PRELOAD LD_DEBUG
  #sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 && \

  start_dbus
  sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'export PULSE_SERVER=127.0.0.1 && \
export GTK_IM_MODULE="fcitx" && \
export QT_IM_MODULE="fcitx" && \
export XMODIFIERS="@im=fcitx" && \
#fcitx5 && \
export GALLIUM_DRIVER=virpipe && \
export MESA_GL_VERSION_OVERRIDE=4.0 && \
zsh ~/tools/rc/allToolsrc; \
zsh '
#dbus-launch --exit-with-session startxfce4'
#startxfce4'
#vncserver -kill :0 && \
#rm -rf /tmp/.X* && \
else
  sdcard_rime=/sdcard/Download/rime
  sdcard_gitconfig=/sdcard/Download/.gitconfig
  sdcard_gitcredentials=/sdcard/Download/.gitcredentials
  rm -rf $DEBIAN_DIR/root/.gitconfig
  test -f $sdcard_gitconfig && sudo ln -s $sdcard_gitconfig $DEBIAN_DIR/root/.gitconfig
  test -f $sdcard_gitcredentials && sudo ln -s $sdcard_gitcredentials $DEBIAN_DIR/root/.gitcredentials
  #复用输入法词库
  rm -rf $DEBIAN_DIR/root/rime
  test -d $sdcard_rime && sudo ln -s $sdcard_rime $DEBIAN_DIR/root/rime
  #解除挂载
  sudo ruri -U $DEBIAN_DIR
  #挂载
  sudo ruri -k -S -m /sdcard /sdcard -p $DEBIAN_DIR
fi
