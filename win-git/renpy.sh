#!/bin/bash
. $(dirname "$0")/toolsinit.sh
#SOFT_VERSION=25.3_1
NAME=renpy
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION=7.4.5
SOFT_ARCH=x86_64
OS=windows
cd ~
#--------------------------------------
#安装 emacs
#--------------------------------------
if [[ $(platform) == *win* ]]; then
  #--------------new .toolsrc-----------------------
  mkdir -p $SOFT_HOME
  case $(arch) in 
    amd64) SOFT_ARCH="";;
    386) SOFT_ARCH="";;
    armhf) SOFT_ARCH=arm;;
    aarch64) SOFT_ARCH=arm;;
  esac
  SOFT_FILE_NAME=${NAME}-${SOFT_VERSION}-sdk${SOFT_ARCH}
  #SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
  SOFT_FILE_PACK=$SOFT_FILE_NAME.zip
  SOFT_URL=https://www.renpy.org/dl/${SOFT_VERSION}/${SOFT_FILE_PACK} 
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  $(cache_unpacker ${SOFT_FILE_PACK} ${SOFT_FILE_NAME})
  rm -rf $SOFT_HOME && \
    mv $(cache_folder)/${SOFT_FILE_NAME} $SOFT_HOME 
  #--------------new .toolsrc-----------------------
  SOFT_ROOT=${SOFT_HOME}/${SOFT_FILE_NAME}
  export PATH=$PATH:${SOFT_ROOT}

  echo 'export PATH=$PATH:'${SOFT_ROOT}>${TOOLSRC}
fi

if [[ $(platform) == *linux* ]]; then
  #--------------new .toolsrc-----------------------
  mkdir -p $SOFT_HOME
  case $(arch) in 
    amd64) SOFT_ARCH="";;
    386) SOFT_ARCH="";;
    armhf) SOFT_ARCH=arm;;
    aarch64) SOFT_ARCH=arm;;
  esac
  SOFT_FILE_NAME=${NAME}-${SOFT_VERSION}-sdk${SOFT_ARCH}
  #SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
  SOFT_FILE_PACK=$SOFT_FILE_NAME.tar.bz2
  SOFT_URL=https://www.renpy.org/dl/${SOFT_VERSION}/${SOFT_FILE_PACK} 
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  $(cache_unpacker ${SOFT_FILE_PACK} ${SOFT_FILE_NAME})
  rm -rf $SOFT_HOME && \
    mv $(cache_folder)/${SOFT_FILE_NAME} $SOFT_HOME 
  #--------------new .toolsrc-----------------------
  SOFT_ROOT=${SOFT_HOME}/${SOFT_FILE_NAME}
  export PATH=$PATH:${SOFT_ROOT}

  echo 'export PATH=$PATH:'${SOFT_ROOT}>${TOOLSRC}
fi

#--------------new .toolsrc-----------------------
#windows下和linux下的不同
#windows 下还需要增加一个HOME的环境变量去系统
