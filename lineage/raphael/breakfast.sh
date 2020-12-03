#!/bin/zsh
cp ./vendorsetup.sh ~/android/lineage/device/xiaomi/raphael/
cd ~/android/lineage
source build/envsetup.sh
#按照官方教程，会莫名其妙报错
#C_VERSION TARGET_PLATFORM_VERSION TARGET_PRODUCT print report_config : invalid parameter name
# 需要去掉本地语义化设置
setopt shwordsplit
export LC_ALL=C

#
#breakfast oneplus3
croot
#lunch lineage_raphael-userdebug
#mka
export LLVM_ENABLE_THREADS=1
brunch lineage_raphael-userdebug
