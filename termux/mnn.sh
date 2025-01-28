#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
ANDROID_LOCAL=/data/local/tmp
AUTHOR=alibaba
ANDROID_NDK=$HOME/tools/android-ndk/android-ndk-r27b
NAME=MNN
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
#SOFT_HOME=${ANDROID_LOCAL}/${NAME}
#sudo mkdir -p $ANDROID_LOCAL/$NAME
#SOFT_VERSION="b4519" #opencl
#LIB_VERSION="2024.10.24"
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

  git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  cd ${SOFT_HOME}
  git pull
  cd project/android
  mkdir -p build_64
  cd build_64/
  #../build_64.sh "-DMNN_LOW_MEMORY=true -DMNN_CPU_WEIGHT_DEQUANT_GEMM=true -DMNN_BUILD_LLM=true -DMNN_SUPPORT_TRANSFORMER_FUSE=true -DMNN_ARM82=true -DMNN_USE_LOGCAT=true -DMNN_OPENCL=true -DLLM_SUPPORT_VISION=true -DMNN_BUILD_OPENCV=true -DMNN_IMGCODECS=true -DLLM_SUPPORT_AUDIO=true -DMNN_BUILD_AUDIO=true -DMNN_BUILD_DIFFUSION=ON -DMNN_SEP_BUILD=ON"
  #加载奇慢，试试关闭低内存
  ../build_64.sh "-DMNN_CPU_WEIGHT_DEQUANT_GEMM=true -DMNN_BUILD_LLM=true -DMNN_SUPPORT_TRANSFORMER_FUSE=true -DMNN_ARM82=true -DMNN_USE_LOGCAT=true -DMNN_OPENCL=true -DLLM_SUPPORT_VISION=true -DMNN_BUILD_OPENCV=true -DMNN_IMGCODECS=true -DLLM_SUPPORT_AUDIO=true -DMNN_BUILD_AUDIO=true -DMNN_BUILD_DIFFUSION=ON -DMNN_SEP_BUILD=ON"
  #复制到 LLM Android 应用项目：
  find . -name "*.so" -exec cp {} ../apps/MnnLlmApp/app/src/main/jniLibs/arm64-v8a/ \;
  #构建 Android 应用项目并安装：
  cd ../apps/MnnLlmApp/
  ./gradlew installDebug
fi
