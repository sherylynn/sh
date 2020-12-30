sudo apt install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev
# install repo in ~/sh/win-git/repo.sh

#set ccache

export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache

ccache -M 100G

# repo sycn
mkdir -p ~/android/maruos-v0.8
cd ~/android/maruos-v0.8

#repo init -u https://github.com/maruos/manifest.git -b maru-0.7 maruos
#repo sync -j 8 --force-sync
#repo init -u https://github.com/pintaf/manifest -b maru-0.7-pintaf --no-clone-bundle --depth=1
repo init -u git://github.com/sherylynn/manifest.git -b maru-0.8 --no-clone-bundle --depth=1
repo sync --jobs=8 --fetch-submodules --current-branch --no-clone-bundle --force-sync
# after finished should 
rm ~/android/maruos
ln -s ~/android/maruos-v0.8 ~/android/maruos
