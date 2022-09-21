#!/bin/bash
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=mesarc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
cd ~
mkdir -p dir
cd dir
curl -LO https://dri.freedesktop.org/libdrm/libdrm-2.4.109.tar.xz

git clone --depth 1 https://gitlab.freedesktop.org/wayland/wayland.git
git clone --depth 1 https://gitlab.freedesktop.org/wayland/wayland-protocols.git
git clone --depth 1 https://github.com/glmark2/glmark2.git
#libdrm 
sudo apt build-dep libdrm -y
tar -xf libdrm-2.4.109.tar.xz
cd libdrm-2.4.109
mkdir build
cd build
meson -Dintel=false -Dradeon=false -Damdgpu=false -Dnouveau=false -Dvmwgfx=false -Dvc4=false ..
#不安装
#sudo ninja install

#libwayland 
cd ~/dir/wayland
sudo apt build-dep wayland -y
mkdir build
cd build
meson -Ddocumentation=false ..
#不安装
#sudo ninja install

#wayland-protocols
cd ~/dir/wayland-protocols
mkdir build
cd build
meson  ..
#不安装
#sudo ninja install 

cd ~
#git clone --depth 1 --branch 22.2 https://gitlab.freedesktop.org/mesa/mesa.git
#rm -rf mesa
sudo cp /usr/include/libdrm/* /usr/include/ -r
git clone --depth 1 --branch 22.1 https://gitlab.freedesktop.org/mesa/mesa.git
#git clone --depth 1 --branch 21.3 https://gitlab.freedesktop.org/mesa/mesa.git
sudo apt-get install meson -y
sudo apt build-dep mesa -y
cd mesa
meson build -D platforms=x11,wayland -D gallium-drivers=swrast,virgl,zink -D vulkan-drivers=freedreno -D dri3=enabled  -D egl=enabled  -D gles2=enabled -D glvnd=true -D glx=dri  -D libunwind=disabled -D osmesa=true  -D shared-glapi=enabled -D microsoft-clc=disabled  -D valgrind=disabled --prefix /usr -D gles1=disabled -D freedreno-kgsl=true

cd build
sudo ninja install

#glmark2
sudo apt install -y libjpeg-dev libpng-dev
cd ~/dir/glmark2
mkdir build
cd build
meson  -Dflavors=x11-gl ..
sudo ninja install


echo 'export MESA_LOADER_DRIVER_OVERRIDE=zink'>${TOOLSRC}
echo 'export GALLIUM_DRIVER=zink'>>${TOOLSRC}
