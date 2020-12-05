#!/bin/zsh
cp ./vendorsetup.sh ~/android/maruos/device/oneplus/oneplus3/
cp ./AndroidProducts.mk ~/android/maruos/device/oneplus/oneplus3/
cp ./maru_oneplus3.mk ~/android/maruos/device/oneplus/oneplus3/
mkdir -p ~/android/maruos/device/oneplus/oneplus3/overlay_maru/daydream/frameworks/base/core/res/res/value/
cp ./config.xml  ~/android/maruos/device/oneplus/oneplus3/overlay_maru/daydream/frameworks/base/core/res/res/value/config.xml
cp ./fstab.qcom  ~/android/maruos/device/oneplus/oneplus3/rootdir/etc/
cp ./init.qcom.rc  ~/android/maruos/device/oneplus/oneplus3/rootdir/etc/
cp ./BoardConfig.mk ~/android/maruos/device/oneplus/oneplus3/
cp ./maru-oneplus3_defconfig ~/android/maruos/kernel/oneplus/msm8996/arch/arm64/configs/
cp ./vendor_init.te ~/android/maruos/device/oneplus/oneplus3/sepolicy/
cp ./system_server.te ~/android/maruos/device/oneplus/oneplus3/sepolicy/
cp ./domain.te ~/android/maruos/system/sepolicy/public/
#cp ./file.te ~/android/maruos/device/qcom/sepolicy/vendor/common/
#cp ./file.te ~/android/maruos/system/sepolicy/public/
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
#lunch maru_oneplus3-userdebug
#mka
#需要用brunch而不是lunch和mka
# 对 ~/android/maruos/system/sepolicy/public/domian.te
# 的1385进行了注释
croot
brunch maru_oneplus3-userdebug
