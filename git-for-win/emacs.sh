# source
INSTALL_PATH=$HOME/tools
EMACS_VERSION=25.3_1
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
  #curl -o ${EMACS_FILE_PACK} http://iso.mirrors.ustc.edu.cn/gnu/emacs/${OS}/${EMACS_FILE_PACK} 
  curl -o ${EMACS_FILE_PACK} http://iso.mirrors.ustc.edu.cn/gnu/emacs/${OS}/${EMACS_FILE_PACK} 
fi

if [ ! -d "${EMACS_FILE_NAME}" ]; then
  #指定解压到emacs_file_name 文件夹
  unzip -q ${EMACS_FILE_PACK} -d ${EMACS_FILE_NAME}
fi
  rm -rf $INSTALL_PATH/emacs && \
  mv ${EMACS_FILE_NAME} $INSTALL_PATH/emacs && \
  rm -rf ${EMACS_FILE_PACK}

#--------------new .toolsrc-----------------------
echo 'test -f ~/.emacsrc && . ~/.emacsrc' >> ~/.bash_profile
#windows下和linux下的不同
echo 'export PATH=$PATH:'${INSTALL_PATH}'/emacs/bin'>~/.emacsrc
