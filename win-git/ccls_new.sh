#!/bin/bash
#------------------init function----------------
. $(dirname "$0")/toolsinit.sh
AUTHOR=MaskRay
NAME=ccls
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)
SOFT_HOME=$(install_path)/${NAME}

#--------------------------
# Install LIBS
#--------------------------
if ! command -v clang && ! command -v lua53 ;then
  if [ ! -d "${INSTALL_PATH}" ]; then
    mkdir $INSTALL_PATH
  fi

  if [[ $(platform) == *macos* ]]; then
    brew install lua51
  elif [[ $(platform) == *linux* ]]; then
    sudo apt install clang libclang-dev cmake llvm-dev -y
  elif [[ $(platform) == *win* ]]; then
  	pacman -Syu mingw64/mingw-w64-x86_64-lua
    #pacman -Sy lua5.1 
  fi
fi

#--------------------------
export PATH="$SOFT_HOME/Release:$PATH"
echo "export PATH=$SOFT_HOME/Release:"'$PATH' > ${TOOLSRC}
cd $(install_path)
git clone --recursive https://github.com/${AUTHOR}/${NAME} $SOFT_HOME
cd $SOFT_HOME
git pull
cmake -H. -BRelease -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH=/usr/lib/llvm-7 \
    -DLLVM_INCLUDE_DIR=/usr/lib/llvm-7/include \
    -DLLVM_BUILD_INCLUDE_DIR=/usr/include/llvm-7/
#cmake -H. -BRelease -DCMAKE_PREFIX_PATH=/usr/lib/llvm-7
#just for debian
cmake --build Release
#cmake --build Release --target install
