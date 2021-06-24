cp ./kebab_18.1.xml ~/android/lineage/.repo/local_manifests/kebab.xml
cp ./../oppo_common/oppo_common_18.1.xml  ~/android/lineage/.repo/local_manifests/oppo_common.xml

cd ~/android/lineage
repo sync -j 8 
#
#以上方法均缺失
