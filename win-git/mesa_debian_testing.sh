#!/bin/bash
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=mesarc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
cd ~
git clone https://github.com/lfdevs/mesa-for-android-container.git
cd mesa-for-android-container
git checkout adreno-main
sudo apt-get install meson -y
sudo apt build-dep mesa -y
meson setup build/ \
  --prefix=/usr \
  -Dplatforms=x11,wayland \
  -Dgallium-drivers=freedreno,zink,virgl,llvmpipe \
  -Dgallium-va=disabled \
  -Dgallium-mediafoundation=disabled \
  -Dvulkan-drivers=freedreno \
  -Dvulkan-layers= \
  -Degl=enabled \
  -Dgles2=enabled \
  -Dglvnd=enabled \
  -Dglx=dri \
  -Dlibunwind=disabled \
  -Dintel-rt=disabled \
  -Dmicrosoft-clc=disabled \
  -Dvalgrind=disabled \
  -Dgles1=disabled \
  -Dfreedreno-kmds=kgsl \
  -Dbuildtype=release
sudo ninja -C build/
sudo ninja -C build/ install
