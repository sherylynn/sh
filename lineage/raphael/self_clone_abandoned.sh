# Extract proprietary blobs
# in https://wiki.lineageos.org/extracting_blobs_from_zips.html#extracting-proprietary-blobs-from-block-based-otas

# or adb your phone and
#

# 需要先 adb shell 到手机 然后执行 su 通过

# 不然会缺失 dashd 文件
# cd  ~/android/lineage/device/oneplus/oneplus3
# ./extract-files.sh
#######
cd ~/android/lineage/vendor
sudo rm -rf ~/android/lineage/vendor/oneplus
git clone https://github.com/TheMuppets/proprietary_vendor_oneplus -b lineage-16.0 oneplus
#fix error not metion in instucntion
# 按照官方教程，会莫名其妙缺少这个文件夹，需要clone回来
cd ~/android/lineage/device
mkdir -p oppo
cd oppo
git clone https://github.com/LineageOS/android_device_oppo_common -b lineage-16.0 common
# 还莫名其妙缺了 kernel 需要手动clone

cd ~/android/lineage
mkdir -p kernel/oneplus
cd ~/android/lineage/kernel/oneplus
git clone https://github.com/LineageOS/android_kernel_oneplus_msm8996 -b lineage-16.0 msm8996
# after finished above 
