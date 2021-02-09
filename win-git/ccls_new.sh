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
    pacman -S mingw-w64-x86_64-clang mingw-w64-x86_64-clang-tools-extra mingw64/mingw-w64-x86_64-polly mingw-w64-x86_64-cmake mingw-w64-x86_64-jq mingw-w64-x86_64-ninja mingw-w64-x86_64-ncurses mingw-w64-x86_64-rapidjson
    #pacman -Sy lua5.1 
  fi
fi

#--------------------------
export PATH="$SOFT_HOME/Release:$PATH"
echo "export PATH=$SOFT_HOME/Release:"'$PATH' > ${TOOLSRC}
cd $(install_path)
git clone --recurse-submodules https://github.com/${AUTHOR}/${NAME} $SOFT_HOME
cd $SOFT_HOME
git pull
if [[ $(platform) == *macos* ]]; then
  brew install lua51
elif [[ $(platform) == *linux* ]]; then
  cmake -H. -BRelease -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH=/usr/lib/llvm-7 \
      -DLLVM_INCLUDE_DIR=/usr/lib/llvm-7/include \
      -DLLVM_BUILD_INCLUDE_DIR=/usr/include/llvm-7/
  cmake --build Release
elif [[ $(platform) == *win* ]]; then
  cmake -H. -BRelease -G Ninja -DCMAKE_CXX_FLAGS=-D__STDC_FORMAT_MACROS
  ninja -C Release
fi
#cmake -H. -BRelease -DCMAKE_PREFIX_PATH=/usr/lib/llvm-7
#just for debian
#cmake --build Release --target install
