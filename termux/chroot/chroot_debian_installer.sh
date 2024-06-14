#!/bin/sh
. $(dirname "$0")/../../win-git/toolsinit.sh
debian_folder_path="/data/data/com.termux/files/home/Desktop/chrootdebian"
debian_run_scrpit="/data/data/com.termux/files/home/sh/termux/chroot/start_debian.sh"
debian_xfce_scrpit="/data/data/com.termux/files/home/sh/termux/chroot/startxfce4_chrootDebian.sh"

#apatch busybox
busybox=/data/adb/ap/bin/busybox
sudo mkdir -p $debian_folder_path

pkg update
pkg install x11-repo root-repo termux-x11-nightly -y
pkg update
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
    DEBIANPATH=$debian_folder_path

    # Check if DEBIANPATH directory exists
    if [ ! -d "$DEBIANPATH" ]; then
        sudo mkdir -p "$DEBIANPATH"
        if [ $? -eq 0 ]; then
            success "Created directory: $DEBIANPATH"
        else
            echo "[!] Error creating directory: $DEBIANPATH. Exiting..."
            goodbye
        fi
    fi

    sudo $busybox mount -o remount,dev,suid /data
    sudo $busybox mount --bind /dev $DEBIANPATH/dev
    sudo $busybox mount --bind /sys $DEBIANPATH/sys
    sudo $busybox mount --bind /proc $DEBIANPATH/proc
    sudo $busybox mount -t devpts devpts $DEBIANPATH/dev/pts

    sudo mkdir -p $DEBIANPATH/dev/shm
    sudo $busybox mount -t tmpfs -o size=256M tmpfs $DEBIANPATH/dev/shm

    sudo mkdir -p $DEBIANPATH/sdcard
    sudo $busybox mount --bind /sdcard $DEBIANPATH/sdcard
    
    sudo $busybox chroot $DEBIANPATH /bin/su - root -c 'apt update -y && apt upgrade -y'
    sudo $busybox chroot $DEBIANPATH /bin/su - root -c 'echo "nameserver 114.114.114.114" > /etc/resolv.conf; \
    echo "127.0.0.1 localhost" > /etc/hosts; \
    groupadd -g 3003 aid_inet; \
    groupadd -g 3004 aid_net_raw; \
    groupadd -g 1003 aid_graphics; \
    usermod -g 3003 -G 3003,3004 -a _apt; \
    usermod -G 3003 -a root; \
    apt update; \
    apt upgrade; \
    apt install emacs vim net-tools sudo git -y; \
    echo "Debian chroot environment configured"'

    if [ $? -eq 0 ]; then
        success "Debian chroot environment configured"
    else
        echo "[!] Error configuring Debian chroot environment. Exiting..."
        goodbye
    fi

    progress "Installing XFCE4..."
    sudo $busybox chroot $DEBIANPATH /bin/su - root -c 'apt update -y && apt install dbus-x11 xfce4 xfce4-terminal firefox-esr fcitx5 fcitx5-rime fonts-wqy-zenhei ttf-wqy-zenhei -y'
}


# Main function
main() {
        download_dir=$debian_folder_path
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
