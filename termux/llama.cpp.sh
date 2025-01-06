#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
AUTHOR=ggerganov
ANDROID_NDK=$HOME/tools/android-ndk/android-ndk-r27b
NAME=llama.cpp
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
LIB_PREFIX_HOME=$(install_path)/OpenCL-Prefix
SOFT_VERSION="b4417" #opencl
#LIB_VERSION="2024.10.24"
LIB_VERSION="2022.05.18"
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
  #pkg install git cmake ccache -y
  pkg install git ccache -y
  # opencl
  pkg install opencl-headers -y
  #pkg install opencl-headers opencl-clhpp opencl-vendor-driver python -y
  #pkg install opencl-headers opencl-vendor-driver python -y
  #pkg install opencl-headers ocl-icd python -y
  # opencl-vendor-driver 会把 ocl-icd 也安装，不合适
  #pkg install opencl-headers python -y #一个提供 opencl-header，一个提供 libopencl.so
  #pkg install opencl-headers opencl-vendor-driver python -y #一个提供 opencl-header，一个提供 libopencl.so
  #pkg install opencl-headers opencl-clhpp clvk python -y
  sudo cp /vendor/lib64/libOpenCL.so /sdcard/Download/libOpenCL.so
  cp /sdcard/Download/libOpenCL.so ${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android

  git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  cd ${SOFT_HOME}
  git pull
  #  rm -rf ${SOFT_HOME} && mkdir -p ${SOFT_HOME}
  #  cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/${SOFT_FILE_NAME}
  #  chmod 777 ${SOFT_HOME}/${SOFT_FILE_NAME}
  cd ${SOFT_HOME}
  git checkout ${SOFT_VERSION}
  #带着下载 curl 一起编译
  #LD_LIBRARY_PATH=/vendor/lib64:$PREFIX/lib:$LD_LIBRARY_PATH cmake \
  cmake \
    -D ANDROID_ABI="arm64-v8a" -D ANDROID_PLATFORM="android-28" \
    -D GGML_CPU_AARCH64=ON -D GGML_RUNTIME_REPACK=ON \
    -D CMAKE_TOOLCHAIN_FILE="${ANDROID_NDK}/build/cmake/android.toolchain.cmake" \
    -D GGML_OPENMP=OFF \
    -D CMAKE_C_FLAGS="-march=armv8.7a" \
    -D CMAKE_CXX_FLAGS="-march=armv8.7a" \
    -D BUILD_SHARED_LIBS=OFF \
    -D GGML_OPENCL=ON -D GGML_OPENCL_USE_ADRENO_KERNELS=ON \
    -B build
  #-D CMAKE_C_FLAGS="-march=armv8.7a" \
  #-D CMAKE_CXX_FLAGS="-march=armv8.7a" \
  # -D BUILD_SHARED_LIBS=OFF \
  #-D CMAKE_PREFIX_PATH="/vendor/lib64" \

  cmake --build build --config Release -j $(nproc)
  SOFT_ROOT=$(install_path)/${NAME}/build/bin
  echo "export PATH=$SOFT_ROOT:"'$PATH' >${TOOLSRC}
  #echo "export PATH=$SOFT_HOME:"'$PATH' >${TOOLSRC}
  tar zcf /sdcard/Download/build.tar.gz build

  #zsh ~/sh/termux/termux_service_${NAME}.sh
  #sh ~/sh/termux/termux_service_${NAME}.sh
  #sv-enable ${NAME}
#  ./systemd_novnc.sh
fi
