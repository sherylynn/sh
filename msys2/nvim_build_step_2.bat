set PATH=c:\msys64\mingw64\bin;%PATH%
set CC=gcc
mkdir .deps
cd .deps
cmake  -G "MinGW Makefiles" ..\third-party\
mingw32-make -j
cd ..
mkdir build
cd build
cmake -G "MinGW Makefiles" -DGPERF_PRG="C:\msys64\usr\bin\gperf.exe" 
::不再指定安装位置,或者安装在直接下面
::因为bat是不识别$HOME
::-DCMAKE_INSTALL_PREFIX="$HOME/neovim" ..
mingw32-make -j
