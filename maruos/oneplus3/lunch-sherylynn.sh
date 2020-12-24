#!/bin/zsh
cd ~/android/maruos
source build/envsetup.sh
#按照官方教程，会莫名其妙报错
#C_VERSION TARGET_PLATFORM_VERSION TARGET_PRODUCT print report_config : invalid parameter name
# 需要去掉本地语义化设置
setopt shwordsplit
export LC_ALL=C
export LD_BIND_NOW=1
export LLVM_ENABLE_THREADS=1
#lunch
#lunch maru_oneplus3-userdebug
#mka
#需要用brunch而不是lunch和mka
# 对 ~/android/maruos/system/sepolicy/public/domian.te
# 的1385进行了注释
croot
brunch maru_oneplus3-userdebug