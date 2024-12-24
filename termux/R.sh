#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
NAME=R
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION="b4337"
#SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
echo "soft version is $SOFT_VERSION"
#https://mirrors.tuna.tsinghua.edu.cn/CRAN/src/base/R-3/R-3.5.3.tar.gz

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
  pkg install git cmake ccache -y
  pkg install libicu libjpeg-turbo libtiff readline

  git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  git pull
  #  rm -rf ${SOFT_HOME} && mkdir -p ${SOFT_HOME}
  #  cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/${SOFT_FILE_NAME}
  #  chmod 777 ${SOFT_HOME}/${SOFT_FILE_NAME}
  cd ${SOFT_HOME}
  git checkout ${SOFT_VERSION}
  #带着下载curl一起编译
  #LD_LIBRARY_PATH=/vendor/lib64:$PREFIX/lib:$LD_LIBRARY_PATH cmake \
  cmake \
    -D LLAMA_CURL=ON \
    -D GGML_OPENCL=ON -D GGML_OPENCL_USE_ADRENO_KERNELS=ON \
    -D GGML_CPU_AARCH64=ON -D GGML_RUNTIME_REPACK=ON \
    -B build
  #-D CMAKE_C_FLAGS="-march=armv8.7a" \
  #-D CMAKE_CXX_FLAGS="-march=armv8.7a" \
  # -D BUILD_SHARED_LIBS=OFF \
  #-D CMAKE_PREFIX_PATH="/vendor/lib64" \

  cmake --build build --config Release -j $(nproc)
  SOFT_ROOT=$(install_path)/${NAME}/build/bin
  echo "export PATH=$SOFT_ROOT:"'$PATH' >${TOOLSRC}
  #echo "export PATH=$SOFT_HOME:"'$PATH' >${TOOLSRC}

  #zsh ~/sh/termux/termux_service_${NAME}.sh
  #sh ~/sh/termux/termux_service_${NAME}.sh
  #sv-enable ${NAME}
#  ./systemd_novnc.sh
fi
