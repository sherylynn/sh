rm ~/android/lineage
ln -s ~/android/lineage-v17.1 ~/android/lineage
mkdir -p ~/android/lineage/.repo/local_manifests/
cp ./raphael-v0.8.xml ~/android/lineage/.repo/local_manifests/raphael.xml

cd ~/android/lineage
#repo sync -j 8  --force-sync
repo sync --jobs=8 --fetch-submodules --current-branch --no-clone-bundle --force-sync
#
#以上方法均缺失
