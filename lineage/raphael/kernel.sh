cd ~/android/lineage/kernel/xiaomi/sm8150
#ARCH=arm64 make raphael_defconfig
#CONFIG=.config lxc-checkconfig
# 手动修复
#ARCH=arm64 make savedefconfig
#mv defconfig 需要的路径 raphael_defconfig
make mrproper
cd ~/android/lineage
rm -rf out
