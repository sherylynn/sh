mkdir -p  ~/android/lineage/.repo/local_manifests/
cp ./lineage_from_corvusrom.xml ~/android/lineage/.repo/local_manifests/raphael.xml

cd ~/android/lineage
repo sync -j 8  --force-sync
#
#以上方法均缺失
