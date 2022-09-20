cd ~
#git clone --depth 1 --branch 22.2 https://gitlab.freedesktop.org/mesa/mesa.git
#git clone --depth 1 --branch 22.1 https://gitlab.freedesktop.org/mesa/mesa.git
rm -rf mesa
git clone --depth 1 --branch 21.3 https://gitlab.freedesktop.org/mesa/mesa.git
sudo apt-get install meson -y
sudo apt build-dep mesa -y
cd mesa
meson build -D platforms=x11,wayland -D gallium-drivers=swrast,virgl,zink -D vulkan-drivers=freedreno -D dri3=enabled  -D egl=enabled  -D gles2=enabled -D glvnd=true -D glx=dri  -D libunwind=disabled -D osmesa=true  -D shared-glapi=enabled -D microsoft-clc=disabled  -D valgrind=disabled --prefix /usr -D gles1=disabled -D freedreno-kgsl=true

cd build
sudo ninja install
