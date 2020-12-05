cp ./oneplus3.xml ~/android/maruos/.repo/local_manifests/oneplus3.xml
cp ./default.xml ~/android/maruos/.repo/manifests/

cd ~/android/maruos
repo sync -j 8 --force-sync
#
#以上方法均缺失
