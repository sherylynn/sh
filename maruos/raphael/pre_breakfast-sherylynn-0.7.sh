rm ~/android/maruos
ln -s ~/android/maruos-v0.7 ~/android/maruos
mkdir -p ~/android/maruos/.repo/local_manifests/
cp ./raphael-sherylynn-v0.7.xml ~/android/maruos/.repo/local_manifests/raphael.xml
#cp ./default.xml ~/android/maruos/.repo/manifests/

cd ~/android/maruos
repo sync -j 8 --force-sync
#
#以上方法均缺失
