cd ~/android/lineage/kernel/oneplus/msm8997
ARCH=arm64 make lineageos_oneplus3_defconfig
CONFIG=.config lxc-checkconfig
# 手动修复
ARCH=arm64 make savedefconfig
mv defconfig 需要的路径 ./maru-oneplus3_defconfig
make mrproper
