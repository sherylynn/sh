echo "net repo init in case-sensitive filesystem"

# repo sycn
mkdir -p ~/android/maruos-v0.9
cd ~/android/maruos-v0.9

#repo init -u https://github.com/maruos/manifest.git -b maru-0.7 maruos
#repo sync -j 8 --force-sync
#repo init -u https://github.com/pintaf/manifest -b maru-0.7-pintaf --no-clone-bundle --depth=1
#repo init -u git://github.com/sherylynn/manifest.git -b maru-0.8 --no-clone-bundle --depth=1
repo init -u git://github.com/sherylynn/manifest.git -b maru-0.9
#repo sync --jobs=8 --fetch-submodules --current-branch --no-clone-bundle --force-sync
repo sync --jobs=8
# after finished should 
rm ~/android/maruos
ln -s ~/android/maruos-v0.9 ~/android/maruos
