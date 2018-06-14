#记得在微软visual stuidio的开发者cmd中执行，不然不生效
cd ~
git clone --recursive https://github.com/aseprite/aseprite.git
cd aseprite
mkdir build
cd build
cmake -G Ninja ..
#----or------------------------------------
call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\VsDevCmd.bat"
cd ~
git clone https://github.com/aseprite/skia.git
cd skia
git checkout aseprite-m67
python tools/git-sync-deps

gn gen out/Release --args="is_official_build=true skia_use_system_expat=false skia_use_system_libjpeg_turbo=false skia_use_system_libpng=false skia_use_system_libwebp=false skia_use_system_zlib=false target_cpu=""x86"" msvc=2017"
ninja -C out/Release

cd ~
cd aseprite
mkdir skia
cd skia
cmake -DUSE_ALLEG4_BACKEND=OFF -DUSE_SKIA_BACKEND=ON -DSKIA_DIR=C:\Users\lynn\skia -G Ninja ..
ninja aseprite
