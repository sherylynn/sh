#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
. $(dirname "$0")/cli.sh
#. ./cli.sh
debian_run_scrpit="/data/data/com.termux/files/home/sh/termux/chroot/cli.sh"
debian_xfce_scrpit="/data/data/com.termux/files/home/sh/termux/chroot/x11.sh"

#sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main@' $PREFIX/etc/apt/sources.list
#apt update && apt upgrade -y && apt autoremove -y
#pkg install x11-repo root-repo termux-x11-nightly qemu-system-aarch64-headless -y
pkg install x11-repo root-repo -y
pkg update
pkg install termux-x11-nightly proot-distro -y
pkg install tsu pulseaudio virglrenderer-android -y

#加入服务
zsh ~/sh/termux/termux_service_virgl.sh
zsh ~/sh/termux/termux_service_pulseaudio.sh

# Function to show farewell message
goodbye() {
  echo "Something went wrong. Exiting..."
  exit 1
}

# Function to show progress message
progress() {
  echo "[+] $1"
}

# Function to show success message
success() {
  echo "[✓] $1"
}

# Function to configure Debian chroot environment
configure_debian_chroot() {
  progress "Configuring Debian chroot environment..."

  # Check if DEBIAN_DIR directory exists
  if [ ! -d "$DEBIAN_DIR" ]; then
    sudo mkdir -p "$DEBIAN_DIR"
    if [ $? -eq 0 ]; then
      success "Created directory: $DEBIAN_DIR"
    else
      echo "[!] Error creating directory: $DEBIAN_DIR. Exiting..."
      goodbye
    fi
  fi

  container_mounted || container_mount
  #git config
  #termux_data_path=/data/data/com.termux/files/home
  #termux_data_path=/data/data/com.termux/files/home/storage/downloads

  #termux_gitcredentials=$termux_data_path/.git-credentials
  #termux_gitconfig=$termux_data_path/.gitconfig
  #termux_rime=$termux_data_path/rime

  #test -f $termux_gitconfig && sudo cp $termux_gitconfig $CHROOT_DIR/root/
  #test -f $termux_gitcredentials && sudo cp $termux_gitcredentials $CHROOT_DIR/root/
  #复用输入法词库
  #rm -rf $CHROOT_DIR/root/rime
  #test -d $termux_rime && sudo ln -s $termux_rime $CHROOT_DIR/root/rime
  sdcard_link

  #unset LD_PRELOAD LD_DEBUG
  #sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'apt update -y && apt upgrade -y'
  unset LD_PRELOAD LD_DEBUG
  #cp ~/sh/debian/sources.list.tuna $CHROOT_DIR/etc/apt/sources.list
  #~/sh/debian/debian_mirror.sh $CHROOT_DIR/etc/apt/sources.list
  /data/data/com.termux/files/home/sh/debian/debian_mirror.sh $CHROOT_DIR/etc/apt/sources.list.d/debian.sources
  sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'echo "nameserver 114.114.114.114" > /etc/resolv.conf; \
    echo "127.0.0.1 localhost" > /etc/hosts; \
    groupadd -g 3003 aid_inet; \
    groupadd -g 3004 aid_net_raw; \
    groupadd -g 1003 aid_graphics; \
    usermod -g 3003 -G 3003,3004 -a _apt; \
    usermod -G 3003 -a root; \
    apt update; \
    apt install git vim wget curl sudo -y; \
    git clone --depth 1 http://github.com/sherylynn/sh  ~/sh; \
    git -C ~/sh pull; \
    ~/sh/debian/debian_mirror.sh; \
    apt update; \
    apt upgrade -y; \
    apt autoremove -y; \
    apt install emacs net-tools zsh -y; \
    echo "Debian chroot environment configured"'

  if [ $? -eq 0 ]; then
    success "Debian chroot environment configured"
  else
    echo "[!] Error configuring Debian chroot environment. Exiting..."
    goodbye
  fi

  progress "Installing XFCE4..."
  unset LD_PRELOAD LD_DEBUG
  #在chroot里面执行配置文件
  #sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'zsh /root/sh/win-git/server_configure.sh'
  sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'zsh /root/sh/win-git/server_configure.sh'

}

# Main function
main() {
  proxy
  #proot下需要先安装再确认是否创建目录，不然就会提示已经安装了debian
  proot-distro install debian
  #proot-distro install debian-oldstable
  configure_debian_chroot
}

# Call the main function
cat <<"EOF"
___  ____ ____ _ ___  _  _ ____ ____ ___ ____ ____    ____ _  _ ____ ____ ____ ___ 
|  \ |__/ |  | | |  \ |\/| |__| [__   |  |___ |__/    |    |__| |__/ |  | |  |  |  
|__/ |  \ |__| | |__/ |  | |  | ___]  |  |___ |  \    |___ |  | |  \ |__| |__|  |  
                                                                                   
EOF

main
