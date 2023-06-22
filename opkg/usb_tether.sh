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
