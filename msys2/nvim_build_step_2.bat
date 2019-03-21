set PATH=c:\msys64\mingw64\bin;%PATH%
set CC=gcc
mkdir .deps
cd .deps
cmake  -G "MinGW Makefiles" ..\third-party\
mingw32-make -j
cd ..
mkdir build
cd build
cmake -G "MinGW Makefiles" -DGPERF_PRG="C:\msys64\usr\bin\gperf.exe" -DCMAKE_INSTALL_PREFIX="$HOME/neovim" ..
mingw32-make -j
