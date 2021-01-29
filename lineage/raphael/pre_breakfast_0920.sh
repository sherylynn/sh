mkdir ~/android/lineage/.repo/local_manifests/
cp ./raphael_0920.xml ~/android/lineage/.repo/local_manifests/

cd ~/android/lineage
repo sync -j 8  --force-sync
#
#以上方法均缺失
