# repo sycn
mkdir -p ~/android/lineage-v18.1
cd ~/android/lineage-v18.1
repo init -u https://github.com/LineageOS/android.git -b lineage-18.1
#repo sync -j 8 --force-sync

repo sync --jobs=8 --force-sync
# after finished should 
rm ~/android/lineage
ln -s ~/android/lineage-v18.1 ~/android/lineage
