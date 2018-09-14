cd ~
PORT=10808
HOST=127.0.0.1
export http_proxy=http://${HOST}:${PORT}/
export https_proxy=http://${HOST}:${PORT}/
git global config http.proxy http://${HOST}:${PORT}/ 
git clone --depth 1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/host/x86_64-w64-mingw32-4.8
cp -Rf x86_64-w64-mingw32-4.8/x86_64-w64-mingw32/include/WinHv*.h /mingw64/x86_64-w64-mingw32/include/
cp -Rf x86_64-w64-mingw32-4.8/x86_64-w64-mingw32/lib/libWinHv*.a /mingw64/x86_64-w64-mingw32/lib/

git clone git://git.qemu-project.org/qemu.git
cd qemu
git checkout v3.0.0
git submodule update --init ui/keycodemapdb
git submodule update --init capstone
git submodule update --init dtc
#./configure --prefix=/qemu --cross-prefix=x86_64-w64-mingw32- --enable-gtk --enable-sdl --enable-whpx --python=python3 --target-list=x86_64-softmmu --disable-werror
make clean
./configure --prefix=/qemu --enable-gtk --enable-sdl --target-list=x86_64-softmmu --disable-werror
#可以查看./configure --help
ln -sf /mingw64/bin/ar /mingw64/bin/x86_64-w64-mingw32-ar
ln -sf /mingw64/bin/nm /mingw64/bin/x86_64-w64-mingw32-nm
ln -sf /mingw64/bin/objcopy /mingw64/bin/x86_64-w64-mingw32-objcopy
ln -sf /mingw64/bin/windres /mingw64/bin/x86_64-w64-mingw32-windres
ln -sf /mingw64/bin/ranlib /mingw64/bin/x86_64-w64-mingw32-ranlib
ln -sf /mingw64/bin/strip /mingw64/bin/x86_64-w64-mingw32-strip
rm -rf /mingw64/bin/x86_64-w64-mingw32-ar /mingw64/bin/x86_64-w64-mingw32-nm /mingw64/bin/x86_64-w64-mingw32-objcopy /mingw64/bin/x86_64-w64-mingw32-windres /mingw64/bin/x86_64-w64-mingw32-ranlib /mingw64/bin/x86_64-w64-mingw32-strip
make -j
make install
cd /mingw64/bin/

#cp -f libgdk_pixbuf-2.0-0.dll libglib-2.0-0.dll libgobject-2.0-0.dll libjpeg-8.dll liblzo2-2.dll libgtk-3-0.dll libpixman-1-0.dll SDL2.dll libpng16-16.dll libgio-2.0-0.dll libgmodule-2.0-0.dll libfontconfig-1.dll libfreetype-6.dll libcairo-gobject-2.dll libepoxy-0.dll libgdk-3-0.dll libcairo-2.dll  ~/qemu/x86_64-softmmu/
#cp -rf *.dll ~/qemu/x86_64-softmmu/
