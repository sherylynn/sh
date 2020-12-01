sudo apt install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev
# install repo in ~/sh/win-git/repo.sh

#set ccache

export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache

ccache -M 100G

# repo sycn
mkdir -p ~/android/lineage
cd ~/android/lineage
repo init -u https://github.com/LineageOS/android.git -b lineage-16.0
repo sync -j 8 --force-sync

# after finished should 
