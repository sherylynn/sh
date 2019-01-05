# source
INSTALL_PATH=$HOME/tools
PYTHON_HOME=$INSTALL_PATH/python
PYTHON_LIB=$PYTHON_HOME/Lib
PYTHON_PACKAGES=$PYTHON_LIB/site-packages
PYTHON_SCRIPTS=$PYTHON_HOME/Scripts
PYTHON_VERSION=3.6.8
PYTHON_ARCH=amd64
GET_PIP=get-pip.py
GET_PIP_PATH=$PYTHON_HOME/$GET_PIP
OS=windows
PYTHON_FILE_NAME=python-${PYTHON_VERSION}-embed-${PYTHON_ARCH}
PYTHON_FILE_PACK=${PYTHON_FILE_NAME}.zip
cd ~
#--------------------------------------
#安装 python
#--------------------------------------
if [ "$(python --version)" != "Python ${PYTHON_VERSION}" ]; then
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
  rm -rf ${PYTHON_HOME} && \
  mv ${PYTHON_FILE_NAME} ${PYTHON_HOME} && \
  rm -rf ${PYTHON_FILE_PACK}
fi
#--------------new .toolsrc-----------------------
echo 'test -f ~/.pythonrc && . ~/.pythonrc' >> ~/.bash_profile
#windows下和linux下的不同
echo 'export PATH=$PATH:'${PYTHON_HOME}>~/.pythonrc
echo 'export PATH=$PATH:'${PYTHON_SCRIPTS}>>~/.pythonrc
echo 'export PYTHONPATH='${PYTHON_HOME}:${PYTHON_LIB}:${PYTHON_PACKAGES}>>~/.pythonrc
export PATH=$PATH:${PYTHON_HOME}
export PATH=$PATH:${PYTHON_SCRIPTS}
export PYTHONPATH=${PYTHON_HOME}:${PYTHON_LIB}:${PYTHON_PACKAGES}


#-------get pip-------------------------------------------
cd $INSTALL_PATH/python
if [ ! -f "${GET_PIP_PATH}" ]; then
  curl -o ${GET_PIP} https://bootstrap.pypa.io/get-pip.py
fi
python ${GET_PIP}
mv python*._pth python._pth.save