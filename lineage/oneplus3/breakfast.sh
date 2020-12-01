#!/bin/zsh
#fix error not metion in instucntion
# 按照官方教程，会莫名其妙缺少这个文件夹，需要clone回来
cd ~/android/lineage/device
mkdir -p oppo
cd oppo
git clone https://github.com/LineageOS/android_device_oppo_common common
# 还莫名其妙缺了 kernel 需要手动clone

cd ~/android/lineage
mkdir -p kernel/oneplus
cd ~/android/lineage/kernel/oneplus
git clone https://github.com/LineageOS/android_kernel_oneplus_msm8996 -b lineage-16.0 msm8996
# after finished above 
cd ~/android/lineage
source build/envsetup.sh
#按照官方教程，会莫名其妙报错
#C_VERSION TARGET_PLATFORM_VERSION TARGET_PRODUCT print report_config : invalid parameter name
# 需要去掉本地语义化设置
setopt shwordsplit
export LC_ALL=C

#
breakfast oneplus3

croot
brunch oneplus3


