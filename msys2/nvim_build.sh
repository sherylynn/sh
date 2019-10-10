#!/bin/bash
#can't build in msys .just in mingw
#pacman -S msys/cmake msys/gperf
SHELL_FOLDER=$(dirname $(readlink -f "$0"))
cd ~
git clone https://github.com/neovim/neovim
cd neovim
git checkout v0.4.2
#mkdir .deps
#cd .deps
#cmake -G "MinGW Makefiles" ../third-party
#mingw32-make
#core_num=$(cat /proc/cpuinfo|grep "processor"|wc -l)
#make -j$core_num
##########################
#msys中纯粹按linux的make，会缺少linux的syscall
#mingw需要先mkdir然后跳出msys shell到cmd里make，这里-G MinGW后会提示不能有git for windows
#看到cmd中cmake的profile有msys的 MSYS Makefiles，但是直接在cmd中Generate不出来
#回到msys中cmake没有MSYS Make file
##########################
rm -rf ~/neovim/nvim_build_step_2.bat
cp ${SHELL_FOLDER}/nvim_build_step_2.bat ~/neovim/
cd ~/neovim/
echo "run nvim_build_step_2.bat!"
start .
