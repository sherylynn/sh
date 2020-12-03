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
