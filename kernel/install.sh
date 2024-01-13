#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
TOOLSRC_NAME=kernel
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${TOOLSRC_NAME}

sudo apt install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev
# install repo in ~/sh/win-git/repo.sh
#brew install bc bison ccache curl flex git gnupg make imagemagick sdl

mkdir -p ~/tools
cd ~/tools
git clone https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b ${SOFT_HOME}/clang
git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 ${SOFT_HOME}/gcc64
git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 ${SOFT_HOME}/gcc32

echo 'export PATH=$PATH:'${SOFT_HOME}/clang/bin>${TOOLSRC}
echo 'export PATH=$PATH:'${SOFT_HOME}/gcc64/bin>>${TOOLSRC}
echo 'export PATH=$PATH:'${SOFT_HOME}/gcc32/bin>>${TOOLSRC}
