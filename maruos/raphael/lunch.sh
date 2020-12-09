#!/bin/zsh
cp ./vendorsetup.sh ~/android/maruos/device/xiaomi/raphael/
cp ./AndroidProducts.mk ~/android/maruos/device/xiaomi/raphael/
cp ./maru_raphael.mk ~/android/maruos/device/xiaomi/raphael/
#darydream
mkdir -p ~/android/maruos/device/xiaomi/raphael/overlay_maru/daydream/frameworks/base/core/res/res/value/
cp ./config.xml  ~/android/maruos/device/xiaomi/raphael/overlay_maru/daydream/frameworks/base/core/res/res/value/config.xml
cp ./fstab.qcom  ~/android/maruos/device/xiaomi/raphael/rootdir/etc/
cp ./init.qcom.rc  ~/android/maruos/device/xiaomi/raphael/rootdir/etc/
cp ./BoardConfig.mk ~/android/maruos/device/xiaomi/raphael/
cp ./maru-raphael_defconfig ~/android/maruos/kernel/xiaomi/sm8150/arch/arm64/configs/
cp ./domain.te ~/android/maruos/system/sepolicy/public/
cp ./maru_files.te ~/android/maruos/vendor/maruos/sepolicy/
cd ~/android/maruos
source build/envsetup.sh
#按照官方教程，会莫名其妙报错
#C_VERSION TARGET_PLATFORM_VERSION TARGET_PRODUCT print report_config : invalid parameter name
# 需要去掉本地语义化设置
setopt shwordsplit
export LC_ALL=C

export LLVM_ENABLE_THREADS=1
#lunch
#lunch maru_raphael-userdebug
#mka
#需要用brunch而不是lunch和mka
# 对 ~/android/maruos/system/sepolicy/public/domian.te
# 的1385进行了注释
croot
brunch maru_raphael-userdebug
