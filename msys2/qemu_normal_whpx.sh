cd ~
PORT=10808
HOST=127.0.0.1
export http_proxy=http://${HOST}:${PORT}/
export https_proxy=http://${HOST}:${PORT}/
git config http.proxy http://${HOST}:${PORT}/

git clone git://git.qemu-project.org/qemu.git
cd qemu
git checkout v3.0.0
git submodule update --init ui/keycodemapdb
git submodule update --init capstone
git submodule update --init dtc
#下载不到
#git clone --depth 1 https://github.com/qemu/dtc

./configure --enable-gtk --enable-sdl \
	    --enable-whpx --static
#--disable-capstone
#make -j 后跟数字就是限制进程最大数目 不跟数字就是直接最大
make -j

