#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
#SOFT_VERSION=25.3_1
NAME=emacs
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION=28.1
SOFT_ARCH=x86_64
OS=windows
cd ~
#--------------------------------------
#安装 emacs
#--------------------------------------
if [[ $(platform) == *win_exe* ]]; then
  PLATFORM=windows
  case $(arch) in 
    amd64) SOFT_ARCH=x86_64;;
    386) SOFT_ARCH=i686;;
  esac

  SOFT_FILE_NAME=${NAME}-${SOFT_VERSION}-${SOFT_ARCH}
  SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
  # init pwd
  cd $HOME

  SOFT_URL=http://mirrors.nju.edu.cn/gnu/${NAME}/${PLATFORM}/${NAME}-$(echo ${SOFT_VERSION}|cut -d '.' -f 1)/${SOFT_FILE_PACK} 
  #if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
  if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
    $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
    $(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)
    
    rm -rf ${SOFT_HOME} && \
      mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME} 
  fi
  #--------------new .toolsrc-----------------------
  SOFT_ROOT=${SOFT_HOME}/bin
  export PATH=$PATH:${SOFT_ROOT}
  echo "set HOME=$(cygpath $HOME -d)">${SOFT_ROOT}/emacs_win.cmd
  echo "emacs" >> ${SOFT_ROOT}emacs_win.cmd

  echo 'export PATH=$PATH:'${SOFT_ROOT}>${TOOLSRC}
fi

if [[ $(platform) == *appimage* ]]; then
	## diffcult to find lib to compile
##  sudo apt install emacs-gtk librime-dev fd-find ripgrep -y
##  sudo apt install cmake libtool-bin libvterm-dev -y
##  sudo apt install libxpm-dev libgtk-3-dev build-essential libjpeg-dev libtiff-dev libgif-dev -y

  case $(arch) in 
    amd64) SOFT_ARCH=x86_64;;
    386) SOFT_ARCH=i686;;
  esac
  SOFT_FILE_NAME=Emacs-${SOFT_VERSION}.glibc2.16-${SOFT_ARCH}
  SOFT_FILE_PACK=$SOFT_FILE_NAME.AppImage
  # init pwd
  cd $HOME

  SOFT_URL=https://github.com/probonopd/Emacs.AppImage/releases/download/continuous/${SOFT_FILE_PACK} 
  if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
    $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
    ## no need to extract
    ##chmod 777 $(cache_folder)/$SOFT_FILE_PACK
    ##$(cache_folder)/$SOFT_FILE_PACK --appimage-extract
    ##rm -rf ${SOFT_HOME}
    ##mv squashfs-root ${SOFT_HOME}
    ##cp ${SOFT_HOME}/AppRun ${SOFT_HOME}/emacs
    mkdir -p ${SOFT_HOME}
    cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/emacs
    chmod 777 ${SOFT_HOME}/emacs
  fi
  #--------------new .toolsrc-----------------------
  SOFT_ROOT=${SOFT_HOME}
  export PATH=$PATH:${SOFT_ROOT}
  echo 'export PATH=$PATH:'${SOFT_ROOT}>${TOOLSRC}
fi

if [[ $(platform) == *linux* ]]; then
	## diffcult to find lib to compile
  sudo apt install libgccjit0 librime-dev fd-find ripgrep -y
  sudo apt install libgccjit-10-dev -y
  sudo apt install libgccjit-8-dev -y
  sudo apt build-dep emacs -y
##  sudo apt install cmake libtool-bin libvterm-dev -y
##  sudo apt install libxpm-dev libgtk-3-dev build-essential libjpeg-dev libtiff-dev libgif-dev -y

  case $(arch) in
    amd64) SOFT_ARCH=x86_64;;
    386) SOFT_ARCH=i686;;
  esac
  SOFT_FILE_NAME=${NAME}-${SOFT_VERSION}
  SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)

  # init pwd
  cd $HOME
  ##SOFT_URL=https://github.com/emacs-mirror/emacs/archive/refs/tags/emacs-$SOFT_VERSION.tar.gz

  if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
    ##$(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
    ##$(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)
    cd $(install_path)
    git clone -b emacs-${SOFT_VERSION} --depth 1 https://github.com/emacs-mirror/emacs.git
    #cd ${SOFT_HOME}
    #git checkout tags/${SOFT_VERSION}
    ##rm -rf ${SOFT_HOME} && \
    ##  mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME} 
  fi
  #--------------new .toolsrc-----------------------
  ##SOFT_ROOT=${SOFT_HOME}/${NAME}-${NAME}-${SOFT_VERSION}
  ##cd $SOFT_ROOT
  cd ${SOFT_HOME}
  ./autogen.sh
  ./configure --with-x --with-native-compilation
  make -j$(nproc)
  sudo make install
  export PATH=$PATH:${SOFT_ROOT}
  echo 'export PATH=$PATH:'${SOFT_ROOT}>${TOOLSRC}
fi
if [[ $(platform) == *win* ]]; then
	## diffcult to find lib to compile
  pacman -S --needed base-devel gcc git\
    mingw-w64-x86_64-toolchain \
    mingw-w64-x86_64-xpm-nox \
    mingw-w64-x86_64-libtiff \
    mingw-w64-x86_64-giflib \
    mingw-w64-x86_64-libpng \
    mingw-w64-x86_64-libjpeg-turbo \
    mingw-w64-x86_64-librsvg \
    mingw-w64-x86_64-lcms2 \
    mingw-w64-x86_64-jansson \
    mingw-w64-x86_64-libxml2 \
    mingw-w64-x86_64-gnutls \
    mingw-w64-x86_64-zlib \
    mingw-w64-x86_64-harfbuzz \
    autoconfig \
    cmake
##  sudo apt install cmake libtool-bin libvterm-dev -y
##  sudo apt install libxpm-dev libgtk-3-dev build-essential libjpeg-dev libtiff-dev libgif-dev -y

  case $(arch) in
    amd64) SOFT_ARCH=x86_64;;
    386) SOFT_ARCH=i686;;
  esac
  SOFT_FILE_NAME=${NAME}-${SOFT_VERSION}
  SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)

  # init pwd
  cd $HOME
  ##SOFT_URL=https://github.com/emacs-mirror/emacs/archive/refs/tags/emacs-$SOFT_VERSION.tar.gz

  if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
    ##$(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
    ##$(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)
    cd $(install_path)
    git clone -b emacs-${SOFT_VERSION} --depth 1 https://github.com/emacs-mirror/emacs.git
    #cd ${SOFT_HOME}
    #git checkout tags/${SOFT_VERSION}
    ##rm -rf ${SOFT_HOME} && \
    ##  mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME} 
  fi
  #--------------new .toolsrc-----------------------
  ##SOFT_ROOT=${SOFT_HOME}/${NAME}-${NAME}-${SOFT_VERSION}
  ##cd $SOFT_ROOT
  cd ${SOFT_HOME}
  ./autogen.sh
  if [[ "$(uname)" == *CGYWIN* ]]; then
    ./configure --with-w32 --without-dbus --with-native-compilation --with-modules
  else
    ./configure --without-dbus --with-native-compilation --with-modules
  fi
  make -j$(nproc)
  make install
  export PATH=$PATH:${SOFT_ROOT}
  echo 'export PATH=$PATH:'${SOFT_ROOT}>${TOOLSRC}
fi
#--------------new .toolsrc-----------------------
#windows下和linux下的不同
#windows 下还需要增加一个HOME的环境变量去系统
