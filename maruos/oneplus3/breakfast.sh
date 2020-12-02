#!/bin/zsh
#cp ./vendorsetup.sh ~/android/maruos/device/oneplus/oneplus3/

cd ~/android/maruos
source build/envsetup.sh
#按照官方教程，会莫名其妙报错
#C_VERSION TARGET_PLATFORM_VERSION TARGET_PRODUCT print report_config : invalid parameter name
# 需要去掉本地语义化设置
setopt shwordsplit
export LC_ALL=C

#

#breakfast oneplus3
rm ~/android/maruos/vendor/nxp/interfaces/Android.bp
sudo ln -s ~/android/maruos/vendor/nxp/opensource/interfaces/nfc/prop_pickup.bp ~/android/maruos/vendor/nxp/interfaces/Android.bp
croot
brunch oneplus3
