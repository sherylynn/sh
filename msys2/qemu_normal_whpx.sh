cd ~
PORT=10808
HOST=127.0.0.1
export http_proxy=http://${HOST}:${PORT}/
export https_proxy=http://${HOST}:${PORT}/
git config http.proxy http://${HOST}:${PORT}/

git clone --depth 1 https://android.googlesource.com/platform/prebuilts/gcc/lin\
ux-x86/host/x86_64-w64-mingw32-4.8
cp -Rf x86_64-w64-mingw32-4.8/x86_64-w64-mingw32/include/WinHv*.h /mingw64/x86_\
64-w64-mingw32/include/
cp -Rf x86_64-w64-mingw32-4.8/x86_64-w64-mingw32/lib/libWinHv*.a /mingw64/x86_6\
4-w64-mingw32/lib/

git clone git://git.qemu-project.org/qemu.git
cd qemu
git checkout v2.12.1
git submodule update --init ui/keycodemapdb
git submodule update --init capstone
git submodule update --init dtc
#下载不到
#git clone --depth 1 https://github.com/qemu/dtc

./configure --enable-gtk --enable-sdl \
	    --enable-whpx --static --disable-werror --disable-capstone
#make -j 后跟数字就是限制进程最大数目 不跟数字就是直接最大
make -j

