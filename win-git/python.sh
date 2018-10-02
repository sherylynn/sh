# source
INSTALL_PATH=$HOME/tools
PYTHON_VERSION=3.7.0
PYTHON_ARCH=amd64
OS=windows
PYTHON_FILE_NAME=python-${PYTHON_VERSION}-embed-${PYTHON_ARCH}
PYTHON_FILE_PACK=${PYTHON_FILE_NAME}.zip
cd ~
#--------------------------------------
#安装 python
#--------------------------------------
if [ ! -d "${INSTALL_PATH}" ]; then
  mkdir $INSTALL_PATH
fi

if [ ! -f "${PYTHON_FILE_PACK}" ]; then
  #淘宝源没法用curl下载
  #curl -o ${PYTHON_FILE_PACK} https://npm.taobao.org/mirrors/python/${PYTHON_VERSION}/${PYTHON_FILE_PACK}
  curl -o ${PYTHON_FILE_PACK} https://www.python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_FILE_PACK}
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
echo 'export PATH=$PATH:'${INSTALL_PATH}'/python'>~/.pythonrc
