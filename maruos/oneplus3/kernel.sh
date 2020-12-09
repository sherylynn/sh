cd ~/android/lineage/kernel/oneplus/msm8996
ARCH=arm64 make lineageos_oneplus3_defconfig
CONFIG=.config lxc-checkconfig
# 手动修复
ARCH=arm64 make savedefconfig
mv defconfig 需要的路径 ./maru-oneplus3_defconfig
make mrproper
# CONFIG_DEVPTS_MULTIPLE_INSTANCES
# is device drivers  -> charact device->unixx98 下方
