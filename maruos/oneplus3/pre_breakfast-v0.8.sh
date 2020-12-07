rm ~/android/maruos
ln -s ~/android/maruos-v0.8 ~/android/maruos
mkdir -p ~/android/maruos/.repo/local_manifests/
cp ./oneplus3-v0.8.xml ~/android/maruos/.repo/local_manifests/oneplus3.xml
#cp ./default.xml ~/android/maruos/.repo/manifests/

cd ~/android/maruos
repo sync -j 8 --force-sync
#
#以上方法均缺失
