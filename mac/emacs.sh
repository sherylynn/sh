#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
NAME=emacs
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_HOME_LIBRIME=$(install_path)/${NAME}/librime
SOFT_HOME_LIBERIME=$(install_path)/${NAME}/liberime
SOFT_VERSION=29

brew install cmake git llvm ninja
brew install ripgrep fd libvterm

brew tap d12frosted/emacs-plus
brew install emacs-plus@$SOFT_VERSION --with-native-comp


mkdir -p $SOFT_HOME
cd $SOFT_HOME
git clone --recursive https://github.com/rime/librime.git $SOFT_HOME_LIBRIME
cd $SOFT_HOME_LIBRIME
####the origin has remove xcode.mk
brew install boost
export LIBRARY_PATH=${LIBRARY_PATH}:/opt/homebrew/opt/icu4c/lib:/usr/local/opt/icu4c/lib
#make xcode/deps
#make xcode/deps/opencc
#make xcode
#./install-boost.sh
make deps
make test
make install

cd $SOFT_HOME
git clone https://github.com/merrickluo/liberime $SOFT_HOME_LIBERIME
export RIME_PATH=$SOFT_HOME_LIBRIME
export EMACS_MAJOR_VERSION=$SOFT_VERSION
cd $SOFT_HOME_LIBERIME
#export rime-emacs-module-header-root=/opt/homebrew/opt/emacs-plus/include

make CFLAGS = -fPIC -O2 -Wall -I $SOFT_HOME_LIBRIME -I $SOFT_HOME_LIBRIME/src/
echo 'export PATH=$PATH:'${SOFT_BIN}>${TOOLSRC}
echo 'export RIME_PATH='${SOFT_HOME_LIBRIME}>>${TOOLSRC}
