cd ~/android/maruos/kernel/xiaomi/sm8150
ARCH=arm64 make raphael_defconfig
CONFIG=.config lxc-checkconfig
# 手动修复

ARCH=arm64 make menuconfig
ARCH=arm64 make savedefconfig
mv defconfig 需要的路径 ./maru-raphael_defconfig
make mrproper
#general setup-> system v ipc
#              -> namespace support -> all
#              -> control group-> cpu sets
#                              -> memory
#                              -> device
#
#file system   -> fuse
#              -> DOS/FAT/NS file system -> all
# deivce drive -> generic driver option -> devtmpfs 
#              -> charactor device -> mult instance
#              -> graphics suport -> displaylink
#              -> usb