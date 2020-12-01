# Extract proprietary blobs
# in https://wiki.lineageos.org/extracting_blobs_from_zips.html#extracting-proprietary-blobs-from-block-based-otas

# or adb your phone and
#

# 需要先 adb shell 到手机 然后执行 su 通过

# 不然会确实 dashd 文件
cd  ~/android/lineage/device/oneplus/oneplus3
./extract-files.sh
#######
#cp ./roomservice.xml ~/android/lineage/.repo/local_manifests/roomservice.xml

#cd ~/android/lineage
#repo sync -j 8 
#
