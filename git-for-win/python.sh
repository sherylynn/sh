# source
INSTALL_PATH=$HOME/tools
PYTHON_VERSION=25.3_1
PYTHON_ARCH=x86_64
OS=windows
PYTHON_FILE_NAME=python-${PYTHON_VERSION}-${PYTHON_ARCH}
PYTHON_FILE_PACK=${PYTHON_FILE_NAME}.zip
cd ~
#--------------------------------------
#安装 python
#--------------------------------------
if [ ! -d "${INSTALL_PATH}" ]; then
  mkdir $INSTALL_PATH
fi

if [ ! -f "${PYTHON_FILE_PACK}" ]; then
  curl -o ${PYTHON_FILE_PACK} http://mirrors.ustc.edu.cn/gnu/python/${OS}/${PYTHON_FILE_PACK} 
  #curl -o ${PYTHON_FILE_PACK} http://iso.mirrors.ustc.edu.cn/gnu/python/${OS}/${PYTHON_FILE_PACK} 
  #curl -o ${PYTHON_FILE_PACK} http://ftp.gnu.org/gnu/python/${OS}/${PYTHON_FILE_PACK} 
  #curl -o python.zip http://iso.mirrors.ustc.edu.cn/gnu/python/windows/python-25.3_1-x86_64.zip
  #curl -o python.zip http://ftp.gnu.org/gnu/python/windows/python-25.3_1-x86_64.zip
fi

if [ ! -d "${PYTHON_FILE_NAME}" ]; then
  #指定解压到python_file_name 文件夹
  unzip -q ${PYTHON_FILE_PACK} -d ${PYTHON_FILE_NAME}
fi
  rm -rf $INSTALL_PATH/python && \
  mv ${PYTHON_FILE_NAME} $INSTALL_PATH/python && \
  rm -rf ${PYTHON_FILE_PACK}

#--------------new .toolsrc-----------------------
echo 'test -f ~/.pythonrc && . ~/.pythonrc' >> ~/.bash_profile
#windows下和linux下的不同
echo 'export PATH=$PATH:'${INSTALL_PATH}'/python/bin'>~/.pythonrc
