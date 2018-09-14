cd ~
PORT=10808
HOST=127.0.0.1
export http_proxy=http://${HOST}:${PORT}/
export https_proxy=http://${HOST}:${PORT}/
git config http.proxy http://${HOST}:${PORT}/

git clone --depth 1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/host/x86_64-w64-mingw32-4.8
cp -Rf x86_64-w64-mingw32-4.8/x86_64-w64-mingw32/include/WinHv*.h /mingw64/x86_64-w64-mingw32/include/
cp -Rf x86_64-w64-mingw32-4.8/x86_64-w64-mingw32/lib/libWinHv*.a /mingw64/x86_64-w64-mingw32/lib/

git clone git://git.qemu-project.org/qemu.git
cd qemu
git checkout v3.0.0
git submodule update --init ui/keycodemapdb
git submodule update --init capstone
git submodule update --init dtc

./configure --cross-prefix=x86_64-w64-mingw32- --enable-gtk --enable-sdl --enable-whpx --python=python3 --target-list=x86_64-softmmu --disable-werror 
#可以查看./configure --help
ln -sf /mingw64/bin/ar /mingw64/bin/x86_64-w64-mingw32-ar
ln -sf /mingw64/bin/nm /mingw64/bin/x86_64-w64-mingw32-nm
ln -sf /mingw64/bin/objcopy /mingw64/bin/x86_64-w64-mingw32-objcopy
ln -sf /mingw64/bin/windres /mingw64/bin/x86_64-w64-mingw32-windres
ln -sf /mingw64/bin/ranlib /mingw64/bin/x86_64-w64-mingw32-ranlib
make -j
