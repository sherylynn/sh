#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
#. ./cli.sh
. $(dirname "$0")/cli.sh
debian_run_scrpit="/data/data/com.termux/files/home/sh/termux/chroot/cli.sh"
debian_xfce_scrpit="/data/data/com.termux/files/home/sh/termux/chroot/x11.sh"

#sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main@' $PREFIX/etc/apt/sources.list
#apt update && apt upgrade -y && apt autoremove -y
pkg install x11-repo root-repo -y
pkg update
pkg install termux-x11-nightly -y
pkg install tsu pulseaudio virglrenderer-android -y

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

# Function to extract file
extract_file() {
    progress "Extracting file..."
    if [ -d "$1/usr/lib/apt" ]; then
        echo "[!] Directory already exists: $1/usr/lib/apt"
        echo "[!] Skipping extraction..."
    else
        sudo tar xpvf "$1/debian12-arm64.tar.gz" -C "$1" --numeric-owner >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            success "File extracted successfully: $1/debian12-arm64"
        else
            echo "[!] Error extracting file. Exiting..."
            goodbye
        fi
    fi
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
    termux_data_path=/data/data/com.termux/files/home
    termux_gitcredentials=$termux_data_path/.git-credentials
    termux_gitconfig=$termux_data_path/.gitconfig

    test -f  $termux_gitconfig && sudo cp $termux_gitconfig $CHROOT_DIR/root/
    test -f  $termux_gitcredentials && sudo cp $termux_gitcredentials $CHROOT_DIR/root/

    #unset LD_PRELOAD LD_DEBUG
    #sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'apt update -y && apt install -f -y && apt upgrade -y'
    unset LD_PRELOAD LD_DEBUG
    sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'echo "nameserver 114.114.114.114" > /etc/resolv.conf; \
    echo "127.0.0.1 localhost" > /etc/hosts; \
    groupadd -g 3003 aid_inet; \
    groupadd -g 3004 aid_net_raw; \
    groupadd -g 1003 aid_graphics; \
    usermod -g 3003 -G 3003,3004 -a _apt; \
    usermod -G 3003 -a root; \
    apt update; \
    apt install git vim wget sudo curl -y; \
    git clone --depth 1 http://github.com/sherylynn/sh  ~/sh; \
    git -C ~/sh pull; \
    ~/sh/debian/debian_mirror.sh; \
    #cp ~/sh/debian/sources.list.deepin /etc/apt/sources.list; \
    apt update; \
    apt upgrade -y; \
    apt autoremove -y; \
    apt install net-tools zsh -y; \
    echo "Debian chroot environment configured"'

    if [ $? -eq 0 ]; then
        success "Debian chroot environment configured"
    else
        echo "[!] Error configuring Debian chroot environment. Exiting..."
        goodbye
    fi

    progress "Installing XFCE4..."
    unset LD_PRELOAD LD_DEBUG
    sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'zsh /root/sh/win-git/server_configure.sh'

    #sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'source /root/sh/win-git/toolsinit.sh && proxy && zsh /root/sh/win-git/move2zsh.sh'
    #sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'source /root/sh/win-git/toolsinit.sh && proxy && zsh /root/sh/win-git/zlua_new.sh && zsh /root/sh/win-git/init_d_noVNC.sh'
    #sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'source /root/sh/win-git/toolsinit.sh && proxy && zsh /root/sh/win-git/noVNC.sh'


}


# Main function
main() {
        download_dir=$DEBIAN_DIR
        if [ ! -d "$download_dir" ]; then
            sudo mkdir -p "$download_dir"
            success "Created directory: $download_dir"
        fi
	proxy
	$(cache_downloader "debian12-arm64.tar.gz" "https://github.com/LinuxDroidMaster/Termux-Desktops/releases/download/Debian/debian12-arm64.tar.gz")
	sudo cp $(cache_folder)/debian12-arm64.tar.gz $download_dir/
        extract_file "$download_dir"
        configure_debian_chroot
}

# Call the main function
cat << "EOF"
___  ____ ____ _ ___  _  _ ____ ____ ___ ____ ____    ____ _  _ ____ ____ ____ ___ 
|  \ |__/ |  | | |  \ |\/| |__| [__   |  |___ |__/    |    |__| |__/ |  | |  |  |  
|__/ |  \ |__| | |__/ |  | |  | ___]  |  |___ |  \    |___ |  | |  \ |__| |__|  |  
                                                                                   
EOF

main
