#!/bin/bash
#pacman -Sy
#pacman -Su
pacman -S git unzip zip
#pacman -S mingw64/mingw-w64-x86_64-lua
#------------------init function----------------
. $(dirname "$0")/../win-git/toolsinit.sh
INSTALL_PATH=$HOME/tools
TOOLSRC_NAME=msys2rc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)
echo 'export HOME=$HOMEPATH' > $TOOLSRC
