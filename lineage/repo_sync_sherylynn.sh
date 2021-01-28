# repo sycn
mkdir -p ~/android/lineage-v17.1
cd ~/android/lineage-v17.1
repo init -u https://github.com/sherylynn/lineage_oss_manifest.git -b lineage_oss
#repo sync -j 8 --force-sync

repo sync --jobs=8 --force-sync
# after finished should 
rm ~/android/lineage
ln -s ~/android/lineage-v17.1 ~/android/lineage
