#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=alibaba
NAME=MNN
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
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
  # 安装必要的依赖
  sudo apt install git cmake build-essential libprotobuf-dev protobuf-compiler -y

  # 克隆或更新代码库
  if [[ ! -d ${SOFT_HOME} ]]; then
    echo "目录 ${SOFT_HOME} 不存在，克隆代码库..."
    git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  else
    echo "目录 ${SOFT_HOME} 已存在，更新代码..."
    cd ${SOFT_HOME}
    git pull
  fi
  cd ${SOFT_HOME}
  git checkout $SOFT_VERSION

  # 生成 schema
  ./schema/generate.sh

  # 配置并编译
  # arm 下先把opencl opengl关掉
  mkdir -p build
  cd build
  cmake \
    -D CMAKE_BUILD_TYPE=Release \
    -D MNN_BUILD_TEST=ON \
    -D MNN_BUILD_BENCHMARK=ON \
    -D MNN_BUILD_SHARED_LIBS=OFF \
    -D MNN_LOW_MEMORY=true \
    -D MNN_CPU_WEIGHT_DEQUANT_GEMM=true \
    -D MNN_BUILD_LLM=true \
    -D MNN_SUPPORT_TRANSFORMER_FUSE=true \
    -D MNN_OPENGL=OFF \
    -D MNN_OPENCL=OFF \
    ..
  cmake --build . --config Release -j $(nproc)

elif [[ $(platform) == *mac* ]]; then
  # 安装必要的依赖
  brew install git cmake protobuf

  # 克隆或更新代码库
  if [[ ! -d ${SOFT_HOME} ]]; then
    echo "目录 ${SOFT_HOME} 不存在，克隆代码库..."
    git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  else
    echo "目录 ${SOFT_HOME} 已存在，更新代码..."
    cd ${SOFT_HOME}
    git pull
  fi
  cd ${SOFT_HOME}
  git checkout $SOFT_VERSION

  # 生成 schema
  ./schema/generate.sh

  # 配置并编译
  mkdir -p build
  cd build
  cmake \
    -D CMAKE_BUILD_TYPE=Release \
    -D MNN_BUILD_TEST=ON \
    -D MNN_BUILD_BENCHMARK=ON \
    -D MNN_BUILD_SHARED_LIBS=OFF \
    -D MNN_BUILD_CONVERTER=ON \
    -D MNN_LOW_MEMORY=true \
    -D MNN_CPU_WEIGHT_DEQUANT_GEMM=true \
    -D MNN_BUILD_LLM=true \
    -D MNN_SUPPORT_TRANSFORMER_FUSE=true \
    -D MNN_METAL=ON \
    -D MNN_OPENCL=OFF \
    -D MNN_OPENGL=OFF \
    ..
  cmake --build . --config Release -j $(sysctl -n hw.ncpu)

elif [[ $(platform) == *win* ]]; then
  # 安装必要的依赖
  pacman -S git cmake mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-protobuf

  # 克隆或更新代码库
  if [[ ! -d ${SOFT_HOME} ]]; then
    echo "目录 ${SOFT_HOME} 不存在，克隆代码库..."
    git clone ${SOFT_GIT_URL} ${SOFT_HOME}
  else
    echo "目录 ${SOFT_HOME} 已存在，更新代码..."
    cd ${SOFT_HOME}
    git pull
  fi
  cd ${SOFT_HOME}
  git checkout $SOFT_VERSION

  # 生成 schema
  ./schema/generate.sh

  # 配置并编译
  mkdir -p build
  cd build
  cmake \
    -D CMAKE_BUILD_TYPE=Release \
    -D MNN_BUILD_TEST=ON \
    -D MNN_BUILD_BENCHMARK=ON \
    ..
  cmake --build . --config Release
fi

# 设置统一的二进制文件路径
SOFT_ROOT="$(install_path)/${NAME}/build"

tee ${TOOLSRC} <<-EOF
export PATH=$SOFT_ROOT:\$PATH
# MNN 相关别名
alias mnn-benchmark="$SOFT_ROOT/MNNBenchmark"
alias mnn-convert="$SOFT_ROOT/MNNConvert"
EOF
