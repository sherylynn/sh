#! bash
INSTALL_PATH=$HOME/tools
#EMACS_VERSION=25.3_1
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=emacsrc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
EMACS_VERSION=26.1
EMACS_ARCH=x86_64
OS=windows
EMACS_FILE_NAME=emacs-${EMACS_VERSION}-${EMACS_ARCH}
EMACS_FILE_PACK=${EMACS_FILE_NAME}.zip
cd ~
#--------------------------------------
#安装 emacs
#--------------------------------------
if [ ! -d "${INSTALL_PATH}" ]; then
  mkdir $INSTALL_PATH
fi

if [ ! -f "${EMACS_FILE_PACK}" ]; then
  #地址变更，需要前置emacs-26
  curl -o ${EMACS_FILE_PACK} http://mirrors.nju.edu.cn/gnu/emacs/${OS}/emacs-$(echo ${EMACS_VERSION}|cut -d '.' -f 1)/${EMACS_FILE_PACK} 
  #curl -o ${EMACS_FILE_PACK} http://mirrors.ustc.edu.cn/gnu/emacs/${OS}/emacs-$(echo ${EMACS_VERSION}|cut -d '.' -f 1)/${EMACS_FILE_PACK} 
  #curl -o ${EMACS_FILE_PACK} http://iso.mirrors.ustc.edu.cn/gnu/emacs/${OSkkEMACS_FILE_PACK} 
  #curl -o ${EMACS_FILE_PACK} http://ftp.gnu.org/gnu/emacs/${OS}/${EMACS_FILE_PACK} 
  #curl -o emacs.zip http://iso.mirrors.ustc.edu.cn/gnu/emacs/windows/emacs-25.3_1-x86_64.zip
  #curl -o emacs.zip http://ftp.gnu.org/gnu/emacs/windows/emacs-25.3_1-x86_64.zip
fi

if [ ! -d "${EMACS_FILE_NAME}" ]; then
  #指定解压到emacs_file_name 文件夹
  unzip -q ${EMACS_FILE_PACK} -d ${EMACS_FILE_NAME}
fi
  rm -rf $INSTALL_PATH/emacs && \
  mv ${EMACS_FILE_NAME} $INSTALL_PATH/emacs && \
  rm -rf ${EMACS_FILE_PACK}

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
