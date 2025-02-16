#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
AUTHOR=ggerganov
NAME=llama.cpp
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
#SOFT_VERSION="b4519" #opencl
SOFT_VERSION="b4708" #opencl
#连接失败
#SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
echo "soft version is $SOFT_VERSION"

case $(platform) in
  macos) PLATFORM=darwin ;;
  win) PLATFORM=windows ;;
  linux) PLATFORM=linux ;;
esac

case $(arch) in
  amd64) SOFT_ARCH=x86_64 ;;
  386) SOFT_ARCH=32-bit ;;
  armhf) SOFT_ARCH=ARM_v6 ;;
  aarch64) SOFT_ARCH=arm64 ;;
esac

# uname Linux .bashrc uname Darwin MINGW64 .bash_profile

SOFT_GIT_URL=https://github.com/${AUTHOR}/${NAME}

if [[ $(platform) == *linux* ]]; then
  #  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  sudo apt install libcurl4-openssl-dev ccache -y

  git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  git pull
  #  rm -rf ${SOFT_HOME} && mkdir -p ${SOFT_HOME}
  #  cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/${SOFT_FILE_NAME}
  #  chmod 777 ${SOFT_HOME}/${SOFT_FILE_NAME}
  cd ${SOFT_HOME}
  git checkout $SOFT_VERSION
  #带着下载 curl 一起编译
  # 带着 repack 功能 看起来运行的时候有 AARCH64_REPACK = 1 应该就是正常的 #4248
  CMAKE_ARGS="-DLLAMA_CURL=ON -DGGML_CPU_AARCH64=ON DCMAKE_C_FLAGS=-march=armv8.7a GGML_RUNTIME_REPACK=ON" cmake --build build --config Release -j $(nproc)
  #3996
  #cmake --build build --config Release -j $(nproc)
  SOFT_ROOT=$(install_path)/${NAME}/build/bin
  echo "export PATH=$SOFT_ROOT:"'$PATH' >${TOOLSRC}
  #echo "export PATH=$SOFT_HOME:"'$PATH' >${TOOLSRC}

  #zsh ~/sh/termux/termux_service_${NAME}.sh
  #sh ~/sh/termux/termux_service_${NAME}.sh
  #sv-enable ${NAME}
#  ./systemd_novnc.sh
elif [[ $(platform) == *win* ]]; then
  git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  cd ${SOFT_HOME}
  git pull
  git checkout $SOFT_VERSION
  pacman -R \
    mingw-w64-ucrt-x86_64-gcc \
    mingw-w64-ucrt-x86_64-cmake \
    mingw-w64-ucrt-x86_64-shaderc
  pacman -S git cmake gcc
  #pacman -S git \
  #  mingw-w64-ucrt-x86_64-gcc \
  #  mingw-w64-ucrt-x86_64-cmake \
  #  mingw-w64-ucrt-x86_64-shaderc
  cmake -B build
  cmake --build build --config Release
  SOFT_ROOT=$(install_path)/${NAME}/build/bin
  echo "export PATH=$SOFT_ROOT:"'$PATH' >${TOOLSRC}
fi
