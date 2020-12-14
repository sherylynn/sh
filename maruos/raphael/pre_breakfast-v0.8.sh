rm ~/android/maruos
ln -s ~/android/maruos-v0.8 ~/android/maruos
mkdir -p ~/android/maruos/.repo/local_manifests/
rm v0.8
ln -s ./v0.8-tingyichen ./v0.8
cp ./v0.8/raphael-v0.8.xml ~/android/maruos/.repo/local_manifests/raphael.xml
#cp ./default.xml ~/android/maruos/.repo/manifests/

cd ~/android/maruos
repo sync -j 8 --force-sync
#
#以上方法均缺失
