#opkg install curl wget git-http screen ca-bundle htop bash zsh ncdu
#opkg install node node-npm go python3 python3-pip lua
#opkg install vim-full vim-runtime
opkg install kmod-usb-net-rndis
opkg install luci-i18n-base-zh-cn
opkg install block-mount e2fsprogs kmod-fs-ext4 kmod-usb-storage kmod-usb2 kmod-usb3
opkg install lsblk
opkg install usbutils
#mount usb driver as overlay
#mount /dev/sda1 test_mount
#cp -r /overlay/* test_mount/
#set mount point in luci ui
# Install packages
opkg update
opkg install hub-ctrl
 
# Save connectivity checking script
cat << "EOF" > /root/wan-watchdog.sh
#!/bin/sh
 
# Fetch WAN gateway
. /lib/functions/network.sh
network_flush_cache
network_find_wan NET_IF
network_get_gateway NET_GW "${NET_IF}"
 
# Check WAN connectivity
TRIES="0"
while [ "${TRIES}" -lt 5 ]
do
    if ping -c 1 -w 3 "${NET_GW}" &> /dev/null
    then exit 0
    else let TRIES++
    fi
done
 
# Restart network
/etc/init.d/network stop
hub-ctrl -h 0 -P 1 -p 0
sleep 1
hub-ctrl -h 0 -P 1 -p 1
/etc/init.d/network start
EOF
chmod +x /root/wan-watchdog.sh
 
# Add cron job
cat << "EOF" >> /etc/crontabs/root
* * * * * /root/wan-watchdog.sh
EOF
