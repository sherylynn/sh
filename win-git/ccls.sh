#!/bin/bash
INSTALL_PATH=$HOME/tools
SOFT_HOME=$INSTALL_PATH/ccls
LIBS_HOME=$INSTALL_PATH/clang_llvm
LIBS_VERSION=7.0.1
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=cclsrc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
if [[ "$(uname)" == *MINGW* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=win
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
  PLATFORM=linux
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=darwin
fi
if [[ "$(uname -a)" == *x86_64* ]]; then
  case $PLATFORM in
    linux) LIBS_ARCH=x86_64-linux-gnu-ubuntu-16.04;;
    darwin) LIBS_ARCH=x86_64-apple-darwin ;LIBS_VERSION=7.0.0;;
  esac
elif [[ "$(uname -a)" == *i686* ]]; then
  LIBS_ARCH=x86
elif [[ "$(uname -a)" == *armv8l* ]]; then
  case $(getconf LONG_BIT) in 
    32) LIBS_ARCH=armv7a-linux-gnueabihf;; 
    64) LIBS_ARCH=aarch64-linux-gnu;;
  esac
elif [[ "$(uname -a)" == *aarch64* ]]; then
  LIBS_ARCH=aarch64-linux-gnu
elif [[ "$(uname -a)" == *armv7l* ]]; then
  LIBS_ARCH=armv7a-linux-gnueabihf
fi
LIBS_FILE_NAME=clang+llvm-${LIBS_VERSION}-${LIBS_ARCH}
if [[ ${PLATFORM} == win ]]; then
  LIBS_FILE_PACK=${LIBS_FILE_NAME}.zip
else
  LIBS_FILE_PACK=${LIBS_FILE_NAME}.tar.xz
fi
#--------------------------
# Install LIBS
#--------------------------
cd ~
if [ ! -d "${LIBS_HOME}/${LIBS_FILE_NAME}" ]; then
  if [ ! -d "${INSTALL_PATH}" ]; then
    mkdir $INSTALL_PATH
  fi

  if [ ! -f "${LIBS_FILE_PACK}" ]; then
    echo https://releases.llvm.org/${LIBS_VERSION}/${LIBS_FILE_PACK}
    curl -o ${LIBS_FILE_PACK} https://releases.llvm.org/${LIBS_VERSION}/${LIBS_FILE_PACK}
  fi

  if [ ! -d "${LIBS_FILE_NAME}" ]; then
    if [[ ${PLATFORM} == win ]]; then
      unzip -q ${LIBS_FILE_PACK} -d ${LIBS_FILE_NAME}
    else
      mkdir ${LIBS_FILE_NAME}
      #tar -xzf ${LIBS_FILE_PACK} -C ${LIBS_FILE_NAME}
      tar -xJf ${LIBS_FILE_PACK} -C ${LIBS_FILE_NAME}
    fi
  fi

  rm -rf $LIBS_HOME && \
  mv ${LIBS_FILE_NAME} $LIBS_HOME && \
  rm -rf ${LIBS_FILE_PACK}
fi
#--------------------------
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi
export PATH="$SOFT_HOME/Release:$PATH"
echo "export PATH=$SOFT_HOME/Release:"'$PATH' >> $TOOLSRC
#sudo apt install clang-7 libclang-7-dev cmake
#ubuntu
#sudo apt install clang libclang-dev
#just for debian
cd $INSTALL_PATH
git clone --depth=1 --recursive https://github.com/MaskRay/ccls
cd $SOFT_HOME
git pull
#up to now raspbian cmake is lower than require
echo ${LIBS_HOME}/${LIBS_FILE_NAME}
cmake -H. -BRelease -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=${LIBS_HOME}/${LIBS_FILE_NAME}
#cmake -H. -BRelease -DCMAKE_PREFIX_PATH=/usr/lib/llvm-7
#just for debian
cmake --build Release
#cmake --build Release --target install
