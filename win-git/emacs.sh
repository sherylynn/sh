#!/bin/bash
. $(dirname "$0")/toolsinit.sh
#SOFT_VERSION=25.3_1
NAME=emacs
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_VERSION=26.1
SOFT_ARCH=x86_64
OS=windows
SOFT_FILE_NAME=emacs-${SOFT_VERSION}-${SOFT_ARCH}
SOFT_FILE_PACK=${SOFT_FILE_NAME}.zip
cd ~
#--------------------------------------
#安装 emacs
#--------------------------------------
if [ ! -d "${INSTALL_PATH}" ]; then
  mkdir $INSTALL_PATH
fi

if [ ! -f "${SOFT_FILE_PACK}" ]; then
  #地址变更，需要前置emacs-26
  curl -o ${SOFT_FILE_PACK} http://mirrors.nju.edu.cn/gnu/emacs/${OS}/emacs-$(echo ${SOFT_VERSION}|cut -d '.' -f 1)/${SOFT_FILE_PACK} 
  #curl -o ${SOFT_FILE_PACK} http://mirrors.ustc.edu.cn/gnu/emacs/${OS}/emacs-$(echo ${SOFT_VERSION}|cut -d '.' -f 1)/${SOFT_FILE_PACK} 
  #curl -o ${SOFT_FILE_PACK} http://iso.mirrors.ustc.edu.cn/gnu/emacs/${OSkkSOFT_FILE_PACK} 
  #curl -o ${SOFT_FILE_PACK} http://ftp.gnu.org/gnu/emacs/${OS}/${SOFT_FILE_PACK} 
  #curl -o emacs.zip http://iso.mirrors.ustc.edu.cn/gnu/emacs/windows/emacs-25.3_1-x86_64.zip
  #curl -o emacs.zip http://ftp.gnu.org/gnu/emacs/windows/emacs-25.3_1-x86_64.zip
fi

if [ ! -d "${SOFT_FILE_NAME}" ]; then
  #指定解压到emacs_file_name 文件夹
  unzip -q ${SOFT_FILE_PACK} -d ${SOFT_FILE_NAME}
fi
  rm -rf $INSTALL_PATH/emacs && \
  mv ${SOFT_FILE_NAME} $INSTALL_PATH/emacs && \
  rm -rf ${SOFT_FILE_PACK}

#--------------new .toolsrc-----------------------
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi
#windows下和linux下的不同
echo 'export PATH=$PATH:'${INSTALL_PATH}'/emacs/bin'>${TOOLSRC}
#windows 下还需要增加一个HOME的环境变量去系统
