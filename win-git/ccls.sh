INSTALL_PATH=$HOME/tools
SOFT_HOME=$INSTALL_PATH/ccls
BASH_DIR=$INSTALL_PATH/rc
SOFT_VERSION=7.0.1
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
  SOFT_ARCH=x64
elif [[ "$(uname -a)" == *i686* ]]; then
  SOFT_ARCH=x86
elif [[ "$(uname -a)" == *armv8l* ]]; then
  case $(getconf LONG_BIT) in 
    32) SOFT_ARCH=armv7l;;
    64) SOFT_ARCH=arm64;;
  esac
elif [[ "$(uname -a)" == *aarch64* ]]; then
  SOFT_ARCH=arm64
elif [[ "$(uname -a)" == *armv7l* ]]; then
  SOFT_ARCH=armv7a
fi

SOFT_FILE_NAME=node-v${SOFT_VERSION}-${PLATFORM}-${SOFT_ARCH}
https://releases.llvm.org/${SOFT_VERSION}/clang+llvm-${SOFT_VERSION}-${SOFT_ARCH}-linux-gnueabihf.tar.xz
https://releases.llvm.org/7.0.1/clang+llvm-7.0.1-aarch64-linux-gnu.tar.xz
if [[ ${PLATFORM} == win ]]; then
  SOFT_FILE_PACK=${SOFT_FILE_NAME}.zip
else
  SOFT_FILE_PACK=${SOFT_FILE_NAME}.tar.gz
fi
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi
export PATH="$SOFT_HOME/Release:$PATH"
echo "export PATH=$SOFT_HOME/Release:"'$PATH' >> $TOOLSRC
sudo apt install clang-7 libclang-7-dev cmake
cd $INSTALL_PATH
git clone --depth=1 --recursive https://github.com/MaskRay/ccls
cd $SOFT_HOME
git pull
cmake -H. -BRelease -DCMAKE_PREFIX_PATH=/usr/lib/llvm-7
cmake --build Release
#cmake --build Release --target install
