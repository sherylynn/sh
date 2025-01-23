#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
AUTHOR=ggerganov
ANDROID_NDK=$HOME/Android/Sdk/ndk/28.0.12674087
#ANDROID_NDK=$HOME/Android/Sdk/ndk/26.3.11579264
NAME=llama.cpp
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
LIB_PREFIX_HOME=$(install_path)/OpenCL-Prefix
mkdir -p $LIB_PREFIX_HOME
SOFT_VERSION="b4368" #opencl
#SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
echo "soft version is $SOFT_VERSION"
LIB_VERSION="2024.10.24"

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
  sudo apt install git cmake ccache -y
  # opencl
  #pkg install opencl-headers opencl-clhpp opencl-vendor-driver python -y
  #pkg install opencl-headers opencl-vendor-driver python -y
  #pkg install opencl-headers ocl-icd python -y
  #pkg install opencl-headers opencl-clhpp clvk python -y
  #需要后续手动下载目标库
  LIB_NAME_1=OpenCL-Headers
  LIB_PACK_1=${LIB_NAME_1}_v${LIB_VERSION}.tar.gz
  $(cache_downloader ${LIB_PACK_1} https://github.com/KhronosGroup/${LIB_NAME_1}/archive/refs/tags/v${LIB_VERSION}.tar.gz)
  cd $(cache_folder)
  tar xvzf ${LIB_PACK_1}
  cd ${LIB_NAME_1}-${LIB_VERSION} &&
    cp -r CL ${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include

  LIB_NAME_2=OpenCL-ICD-Loader
  LIB_PACK_2=${LIB_NAME_2}_v${LIB_VERSION}.tar.gz
  $(cache_downloader ${LIB_PACK_2} https://github.com/KhronosGroup/${LIB_NAME_2}/archive/refs/tags/v${LIB_VERSION}.tar.gz)
  cd $(cache_folder)
  tar xvzf ${LIB_PACK_2}
  cd ${LIB_NAME_2}-${LIB_VERSION}
  mkdir -p build_ndk && cd build_ndk
  cmake .. -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_TOOLCHAIN_FILE=${ANDROID_NDK}/build/cmake/android.toolchain.cmake \
    -D OPENCL_ICD_LOADER_HEADERS_DIR=${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include \
    -D ANDROID_ABI=arm64-v8a \
    -D ANDROID_PLATFORM=35 \
    -D ANDROID_STL=c++_shared
  make
  cp libOpenCL.so ${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android
  git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  #  rm -rf ${SOFT_HOME} && mkdir -p ${SOFT_HOME}
  #  cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/${SOFT_FILE_NAME}
  #  chmod 777 ${SOFT_HOME}/${SOFT_FILE_NAME}
  cd ${SOFT_HOME}
  git pull
  git checkout ${SOFT_VERSION}
  #带着下载curl一起编译
  cmake \
    -D ANDROID_ABI="arm64-v8a" -D ANDROID_PLATFORM="android-35" \
    -D GGML_CPU_AARCH64=ON -D GGML_RUNTIME_REPACK=ON \
    -D CMAKE_TOOLCHAIN_FILE="${ANDROID_NDK}/build/cmake/android.toolchain.cmake" \
    -D GGML_OPENMP=OFF \
    -D CMAKE_C_FLAGS="-march=armv8.7a" \
    -D CMAKE_CXX_FLAGS="-march=armv8.7a" \
    -D BUILD_SHARED_LIBS=OFF \
    -D GGML_OPENCL=ON -D GGML_OPENCL_USE_ADRENO_KERNELS=ON \
    -B build
  #android is no curl
  #-D LLAMA_CURL=ON \
  #-D CMAKE_PREFIX_PATH="$LIB_PREFIX_HOME" \

  cmake --build build --config Release -j $(nproc)
  SOFT_ROOT=$(install_path)/${NAME}/build/bin
  echo "export PATH=$SOFT_ROOT:"'$PATH' >${TOOLSRC}
  #echo "export PATH=$SOFT_HOME:"'$PATH' >${TOOLSRC}

  #zsh ~/sh/termux/termux_service_${NAME}.sh
  #sh ~/sh/termux/termux_service_${NAME}.sh
  #sv-enable ${NAME}
#  ./systemd_novnc.sh
fi
