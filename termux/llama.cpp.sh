#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
ANDROID_LOCAL=/data/local/tmp
AUTHOR=ggerganov
ANDROID_NDK=$HOME/tools/android-ndk/android-ndk-r27b
NAME=llama.cpp
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
#SOFT_HOME=$(install_path)/${NAME}
SOFT_HOME=${ANDROID_LOCAL}/${NAME}
sudo mkdir -p $ANDROID_LOCAL/$NAME
SOFT_VERSION="b4585" #opencl
LIB_VERSION="2024.10.24"
#LIB_VERSION="2022.05.18"
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
  #pkg remove opencl-vendor-driver -y
  #pkg install opencl-headers -y
  #sudo cp /vendor/lib64/libOpenCL.so /sdcard/Download/libOpenCL.so
  #cp /sdcard/Download/libOpenCL.so ${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android
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

  sudo git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  cd ${SOFT_HOME}
  sudo git pull
  sudo git checkout ${SOFT_VERSION}
  sudo cmake \
    -D ANDROID_ABI="arm64-v8a" -D ANDROID_PLATFORM="android-28" \
    -D GGML_CPU_AARCH64=ON -D GGML_RUNTIME_REPACK=ON \
    -D CMAKE_TOOLCHAIN_FILE="${ANDROID_NDK}/build/cmake/android.toolchain.cmake" \
    -D GGML_OPENMP=OFF \
    -D CMAKE_C_FLAGS="-march=armv8.7a" \
    -D CMAKE_CXX_FLAGS="-march=armv8.7a" \
    -D BUILD_SHARED_LIBS=OFF \
    -D GGML_OPENCL=ON -D GGML_OPENCL_USE_ADRENO_KERNELS=ON \
    -B build

  sudo cmake --build build --config Release -j $(nproc)
  SOFT_ROOT=$(install_path)/${NAME}/build/bin
  echo "export PATH=$SOFT_ROOT:"'$PATH' >${TOOLSRC}
  #echo "export PATH=$SOFT_HOME:"'$PATH' >${TOOLSRC}
  #tar zcf /sdcard/Download/build.tar.gz build
fi
