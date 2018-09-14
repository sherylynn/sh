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
git submodule update --init ui/keycodemapdb
git submodule update --init capstone
git submodule update --init dtc

./configure --cross-prefix=x86_64-w64-mingw32- --enable-gtk --enable-sdl \
--enable-whpx --python=python3 --target-list=x86_64-softmmu
