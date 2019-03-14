sudo apt install clang-7 libclang-7-dev cmake
git clone --depth=1 --recursive https://github.com/MaskRay/ccls
cd ccls
cmake -H. -BRelease -DCMAKE_PREFIX_PATH=/usr/lib/llvm-7
cmake --build Release
#cmake --build Release --target install
