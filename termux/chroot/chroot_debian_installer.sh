#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
. ./start_debian.sh
debian_run_scrpit="/data/data/com.termux/files/home/sh/termux/chroot/start_debian.sh"
debian_xfce_scrpit="/data/data/com.termux/files/home/sh/termux/chroot/startxfce4_chrootDebian.sh"

sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/apt/termux-main stable main@' $PREFIX/etc/apt/sources.list
apt update && apt upgrade -y
pkg install x11-repo root-repo termux-x11-nightly -y
apt update
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

    # Check if CHROOT_DIR directory exists
    if [ ! -d "$CHROOT_DIR" ]; then
        sudo mkdir -p "$CHROOT_DIR"
        if [ $? -eq 0 ]; then
            success "Created directory: $CHROOT_DIR"
        else
            echo "[!] Error creating directory: $CHROOT_DIR. Exiting..."
            goodbye
        fi
    fi

    container_mounted || container_mount
    
    sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'apt update -y && apt upgrade -y'
    sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'echo "nameserver 114.114.114.114" > /etc/resolv.conf; \
    echo "127.0.0.1 localhost" > /etc/hosts; \
    groupadd -g 3003 aid_inet; \
    groupadd -g 3004 aid_net_raw; \
    groupadd -g 1003 aid_graphics; \
    usermod -g 3003 -G 3003,3004 -a _apt; \
    usermod -G 3003 -a root; \
    apt update; \
    apt upgrade; \
    apt install git vim -y; \
    git clone --depth 1 http://github.com/sherylynn/sh  ~/sh; \
    ~/sh/debian/debian_mirror.sh; \
    apt update; \
    apt upgrade; \
    apt install emacs net-tools sudo zsh -y; \
    echo "Debian chroot environment configured"'

    if [ $? -eq 0 ]; then
        success "Debian chroot environment configured"
    else
        echo "[!] Error configuring Debian chroot environment. Exiting..."
        goodbye
    fi

    progress "Installing XFCE4..."
    sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'apt update -y && apt install dbus-x11 xfce4 xfce4-terminal firefox-esr chromium fcitx5 fcitx5-rime fonts-wqy-zenhei ttf-wqy-zenhei -y'

    sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'chsh /bin/zsh'
    sudo $busybox chroot $CHROOT_DIR /bin/su - root -c 'source /root/sh/win-git/toolsinit.sh && proxy && /root/sh/win-git/move2zsh.sh && /root/sh/win-git/noVNC.sh'


}


# Main function
main() {
        download_dir=$CHROOT_DIR
        if [ ! -d "$download_dir" ]; then
            sudo mkdir -p "$download_dir"
            success "Created directory: $download_dir"
        fi
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