#!/bin/sh
debian_folder_path="/data/data/com.termux/files/home/Desktop/chrootdebian"
debian_run_scrpit="/data/data/com.termux/files/home/sh/termux/chroot/start_debian.sh"
debian_xfce_scrpit="/data/data/com.termux/files/home/sh/termux/chroot/startxfce4_chrootDebian.sh"

mkdir -p $debian_folder_path

# Function to show farewell message
goodbye() {
    echo -e "\e[1;31m[!] Something went wrong. Exiting...\e[0m"
    exit 1
}

# Function to show progress message
progress() {
    echo -e "\e[1;36m[+] $1\e[0m"
}

# Function to show success message
success() {
    echo -e "\e[1;32m[✓] $1\e[0m"
}

# Function to download file
download_file() {
    progress "Downloading file..."
    if [ -e "$1/$2" ]; then
        echo -e "\e[1;33m[!] File already exists: $2\e[0m"
        echo -e "\e[1;33m[!] Skipping download...\e[0m"
    else
        wget -O "$1/$2" "$3"
        if [ $? -eq 0 ]; then
            success "File downloaded successfully: $2"
        else
            echo -e "\e[1;31m[!] Error downloading file: $2. Exiting...\e[0m"
            goodbye
        fi
    fi
}

# Function to extract file
extract_file() {
    progress "Extracting file..."
    if [ -d "$1/debian12-arm64" ]; then
        echo -e "\e[1;33m[!] Directory already exists: $1/debian12-arm64\e[0m"
        echo -e "\e[1;33m[!] Skipping extraction...\e[0m"
    else
        tar xpvf "$1/debian12-arm64.tar.gz" -C "$1" --numeric-owner >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            success "File extracted successfully: $1/debian12-arm64"
        else
            echo -e "\e[1;31m[!] Error extracting file. Exiting...\e[0m"
            goodbye
        fi
    fi
}

# Function to download and execute script
download_and_execute_script() {
    progress "Downloading script..."
    if [ -e '$debian_run_scrpit' ]; then
        echo -e "\e[1;33m[!] Script already exists: /data/data/com.termux/files/home/sh/termux/chroot/start_debian.sh\e[0m"
        echo -e "\e[1;33m[!] Skipping download...\e[0m"
    else
        wget -O $debian_run_scrpit "https://raw.githubusercontent.com/LinuxDroidMaster/Termux-Desktops/main/scripts/chroot/debian/start_debian.sh"
        if [ $? -eq 0 ]; then
            success "Script downloaded successfully: start_debian.sh"
            progress "Setting script permissions..."
            chmod +x $debian_run_scrpit
            success "Script permissions set"
        else
            echo -e "\e[1;31m[!] Error downloading script. Exiting...\e[0m"
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
        mkdir -p "$DEBIANPATH"
        if [ $? -eq 0 ]; then
            success "Created directory: $DEBIANPATH"
        else
            echo -e "\e[1;31m[!] Error creating directory: $DEBIANPATH. Exiting...\e[0m"
            goodbye
        fi
    fi

    busybox mount -o remount,dev,suid /data
    busybox mount --bind /dev $DEBIANPATH/dev
    busybox mount --bind /sys $DEBIANPATH/sys
    busybox mount --bind /proc $DEBIANPATH/proc
    busybox mount -t devpts devpts $DEBIANPATH/dev/pts

    mkdir $DEBIANPATH/dev/shm
    busybox mount -t tmpfs -o size=256M tmpfs $DEBIANPATH/dev/shm

    mkdir $DEBIANPATH/sdcard
    busybox mount --bind /sdcard $DEBIANPATH/sdcard
    
    busybox chroot $DEBIANPATH /bin/su - root -c 'apt update -y && apt upgrade -y'
    busybox chroot $DEBIANPATH /bin/su - root -c 'echo "nameserver 114.114.114.114" > /etc/resolv.conf; \
    echo "127.0.0.1 localhost" > /etc/hosts; \
    groupadd -g 3003 aid_inet; \
    groupadd -g 3004 aid_net_raw; \
    groupadd -g 1003 aid_graphics; \
    usermod -g 3003 -G 3003,3004 -a _apt; \
    usermod -G 3003 -a root; \
    apt update; \
    apt upgrade; \
    apt install emacs vim net-tools sudo git; \
    echo "Debian chroot environment configured"'

    if [ $? -eq 0 ]; then
        success "Debian chroot environment configured"
    else
        echo -e "\e[1;31m[!] Error configuring Debian chroot environment. Exiting...\e[0m"
        goodbye
    fi

    # Prompt for username
    progress "Setting up user account..."
    echo -n "Enter username for Debian chroot environment: "
    read USERNAME

    # Add the user
    busybox chroot $DEBIANPATH /bin/su - root -c "adduser $USERNAME"

    # Add user to sudoers
    progress "Configuring sudo permissions..."
    busybox chroot $DEBIANPATH /bin/su - root -c "echo '$USERNAME ALL=(ALL:ALL) ALL' >> /etc/sudoers"
    busybox chroot $DEBIANPATH /bin/su - root -c "usermod -aG aid_inet $USERNAME"

    success "User account set up and sudo permissions configured"

    progress "Installing XFCE4..."
    busybox chroot $DEBIANPATH /bin/su - root -c 'apt update -y && apt install dbus-x11 xfce4 xfce4-terminal -y'
    download_startxfce4_script
}


# Function to download startxfce4_chrootDebian.sh script
download_startxfce4_script() {
    progress "Downloading startxfce4_chrootDebian.sh script..."
    if [ "$DE_OPTION" -eq 1 ]; then
        wget -O $debian_xfce_scrpit "https://raw.githubusercontent.com/LinuxDroidMaster/Termux-Desktops/main/scripts/chroot/debian/startxfce4_chrootDebian.sh"
        if [ $? -eq 0 ]; then
            success "startxfce4_chrootDebian.sh script downloaded successfully"
        else
            echo -e "\e[1;31m[!] Error downloading startxfce4_chrootDebian.sh script. Exiting...\e[0m"
            goodbye
        fi
    fi
}

modify_startfile_with_username() {
    success "Set start_debian.sh file with user name..."
    sed -i "s/droidmaster/$USERNAME/g" $debian_run_scrpit
}

# Main function
main() {
    if [ "$(whoami)" != "root" ]; then
        echo -e "\e[1;31m[!] This script must be run as root. Exiting...\e[0m"
        goodbye
    else
        download_dir=$debian_folder_path
        if [ ! -d "$download_dir" ]; then
            mkdir -p "$download_dir"
            success "Created directory: $download_dir"
        fi
        download_file "$download_dir" "debian12-arm64.tar.gz" "https://github.com/LinuxDroidMaster/Termux-Desktops/releases/download/Debian/debian12-arm64.tar.gz"
        extract_file "$download_dir"
        download_and_execute_script "$download_dir"
        configure_debian_chroot
        modify_startfile_with_username
    fi
}

# Call the main function
echo -e "\e[32m"
cat << "EOF"
___  ____ ____ _ ___  _  _ ____ ____ ___ ____ ____    ____ _  _ ____ ____ ____ ___ 
|  \ |__/ |  | | |  \ |\/| |__| [__   |  |___ |__/    |    |__| |__/ |  | |  |  |  
|__/ |  \ |__| | |__/ |  | |  | ___]  |  |___ |  \    |___ |  | |  \ |__| |__|  |  
                                                                                   
EOF
echo -e "\e[0m"

main
