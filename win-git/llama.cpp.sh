#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=ggerganov
NAME=llama.cpp
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION="b4667" #编译不了，linux下认不出cpu
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
  sudo apt install libcurl4-openssl-dev ccache clang libomp-dev -y
  #GGML_NATIVE 需要指定clang，发现还是不好用，手动去指定了
  #openmp需要libomp-dev

  git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  git pull
  #  rm -rf ${SOFT_HOME} && mkdir -p ${SOFT_HOME}
  #  cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/${SOFT_FILE_NAME}
  #  chmod 777 ${SOFT_HOME}/${SOFT_FILE_NAME}
  cd ${SOFT_HOME}
  git checkout $SOFT_VERSION
  #带着下载curl一起编译
  # 带着repack功能 看起来运行的时候有 AARCH64_REPACK = 1应该就是正常的 #4248
  cmake \
    -D GGML_NATIVE=OFF -D GGML_CPU_ARM_ARCH=armv8.7-a+dotprod+i8mm+nosve \
    -D CMAKE_C_COMPILER="/usr/bin/gcc" \
    -D CMAKE_CXX_COMPILER="/usr/bin/g++" \
    -D GGML_RUNTIME_REPACK=ON \
    -B build
  #-D GGML_CPU_AARCH64=ON \
  #-D GGML_NATIVE=ON \
  #-D CMAKE_C_FLAGS="-march=armv8.7-a" \
  #-D CMAKE_CXX_FLAGS="-march=armv8.7-a" \
  #-D GGML_NATIVE=OFF -D GGML_CPU_ARM_ARCH=armv8.7-a+dotprod+i8mm+nosve \
  #-D CMAKE_C_COMPILER="/usr/bin/clang" \
  #-D CMAKE_CXX_COMPILER="/usr/bin/clang" \
  cmake --build build --config Release -j $(nproc)

  #zsh ~/sh/termux/termux_service_${NAME}.sh
  #sh ~/sh/termux/termux_service_${NAME}.sh
  #sv-enable ${NAME}
#  ./systemd_novnc.sh
elif [[ $(platform) == *win* ]]; then
  git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  cd ${SOFT_HOME}
  git pull
  git checkout $SOFT_VERSION
  pacman -R cmake
  pacman -S git \
    mingw-w64-ucrt-x86_64-gcc \
    mingw-w64-ucrt-x86_64-cmake \
    mingw-w64-ucrt-x86_64-shaderc
  cmake -B build
  cmake --build build --config Release
fi
SOFT_ROOT=$(install_path)/${NAME}/build/bin
tee ${TOOLSRC} <<-EOF
export PATH=$SOFT_ROOT:'$PATH'
alias ll-sex='llama-server -m /sdcard/Download/MN-Halide-12b-v1.0.Q4_0.gguf --host 0.0.0.0 --port 8888 -ngl 0 -t 2'
alias ll-story='llama-cli -m /sdcard/Download/MN-Halide-12b-v1.0.Q4_0.gguf --chat-template deepseek3 -p "你是一个淫荡的女人" -no-cnv -t 2 --temp 0.6 --repeat-penalty 1.1 --cpu-range 4-5 --cpu-strict 1' 
EOF
