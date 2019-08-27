#!/bin/bash
# source
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=pythonrc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)
PLATFORM=$(platform)
PIP_USERBASE=$INSTALL_PATH/python-pip

#PIP3_PATH=$(python3 -m site --user-base)"/bin"
#export PATH=$PATH:$PIP3_PATH
#echo "export PATH=\$PATH:"${PIP3_PATH} >> ~/.bashrc

PYTHON_HOME=$INSTALL_PATH/python
#PYTHON_VERSION=3.6.8
PYTHON_VERSION=3.7.1
PYTHON_SHOTVERSION=${PYTHON_VERSION//./}
PYTHON_PREFIX=${PYTHON_SHOTVERSION:0:2}
PYTHON_LIB=$PYTHON_HOME/Lib
PYTHON_ZIP=$PYTHON_HOME/python${PYTHON_PREFIX}.zip
PYTHON_PACKAGES=$PYTHON_LIB/site-packages
PYTHON_SCRIPTS=$PYTHON_HOME/Scripts
PYTHON_ARCH=amd64
GET_PIP=get-pip.py
GET_PIP_PATH=$PYTHON_HOME/$GET_PIP
PIP_BIN_PATH=$PIP_USERBASE/Python$PYTHON_PREFIX/Scripts
PIP_PACKAGES=$PIP_USERBASE/Python$PYTHON_PREFIX/site-packages
OS=windows
PYTHON_FILE_NAME=python-${PYTHON_VERSION}-embed-${PYTHON_ARCH}
PYTHON_FILE_PACK=${PYTHON_FILE_NAME}.zip
PYLINT_ON=1
PYTHON_SOURCE_NAME=Python-${PYTHON_VERSION}
PYTHON_SOURCE_FILE=${PYTHON_SOURCE_NAME}.tar.xz
cd ~
#------------------win function-----------------
echo $(dirname "$0")
. $(dirname "$0")/winPath.sh
#--------------------------------------
#安装 python
#--------------------------------------
if [[ $PLATFORM == 'win' ]];then
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
  #--------------安装 python Lib-----pylint 会用到-------------
  if [ ! -d "${PYTHON_LIB}" ]; then
    #下载源文件，会用到里面的lib
    if [ ! -f "${PYTHON_SOURCE_FILE}" ]; then
      curl -o ${PYTHON_SOURCE_FILE} https://www.python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_SOURCE_FILE}
    fi
    if [ ! -d "${PYTHON_SOURCE_NAME}" ]; then
      tar -xf ${PYTHON_SOURCE_FILE}
    fi

    mv ${PYTHON_SOURCE_NAME}/Lib ${PYTHON_LIB} && \
    rm -rf ${PYTHON_SOURCE_NAME} ${PYTHON_SOURCE_FILE}
  fi
  #--------------new .toolsrc-----------------------
  cd ${PYTHON_HOME}
  mv python*._pth python._pth.save
  #-----------pip install path-----------------------------------
  if [ ! -d "${PIP_USERBASE}" ]; then
    mkdir ${PIP_USERBASE}
  fi
  #---------------------------------------------  需要有路径不然没user-site
  export PATH=$PATH:${PYTHON_HOME}
  export PATH=$PATH:${PYTHON_SCRIPTS}
  export PATH=$PATH:${PIP_BIN_PATH}
  export PYTHONPATH=${PYTHON_HOME}:${PYTHON_LIB}:${PYTHON_PACKAGES}:${PYTHON_ZIP}:${PIP_BIN_PATH}
  export PYTHONUSERBASE=$(winDoublePath $PIP_USERBASE)
  #------------------------------------
  echo $(winDoublePath $PIP_USERBASE)
  python -m site
  python -m site --user-site
  #--------------------------------
  echo 'export PATH=$PATH:'${PYTHON_HOME}>$TOOLSRC
  echo 'export PATH=$PATH:'${PYTHON_SCRIPTS}>>$TOOLSRC
  echo 'export PATH=$PATH:'${PIP_BIN_PATH}>>$TOOLSRC
  echo 'export PYTHONPATH='${PYTHON_HOME}:${PYTHON_LIB}:${PYTHON_PACKAGES}:${PYTHON_ZIP}:${PIP_BIN_PATH}>>$TOOLSRC
  echo 'export PYTHONUSERBASE='$(winDoublePath ${PIP_USERBASE})>>$TOOLSRC

  #-------get pip-------------------------------------------
  if [ ! -f "${GET_PIP_PATH}" ]; then
    curl -o ${GET_PIP} https://bootstrap.pypa.io/get-pip.py
  fi
  echo Install pip
  if [[ "$(pip --version)" != *from* ]]; then
    python ${GET_PIP} --user
  fi
else
  if [ ! -d "${PIP_USERBASE}" ]; then
    mkdir ${PIP_USERBASE}
  fi
  export PATH=$PATH:${PIP_BIN_PATH}
  export PYTHONPATH=${PIP_BIN_PATH}
  export PYTHONUSERBASE=$PIP_USERBASE

  echo 'export PATH=$PATH:'${PIP_BIN_PATH}>$TOOLSRC
  echo 'export PYTHONPATH='${PIP_BIN_PATH}>>$TOOLSRC
  echo 'export PYTHONUSERBASE='${PIP_USERBASE}>>$TOOLSRC

fi
#  ----windows bat----
if [[ $WIN_PATH ]]; then
  setx PYTHONHOME $(winPath ${PYTHON_HOME})
  setx PYTHONPATH $(winPath ${PYTHONPATH})
  setx PYTHONUSERBASE $(winPath ${PIP_USERBASE})
  setx PYTHON_BIN $(winPath ${PYTHON_HOME})";"$(winPath ${PYTHON_SCRIPTS})";"$(winPath ${PIP_BIN_PATH}/../Scripts)

  # 替换掉linux path中:为;因为最后一个$PATH中的值是没有:分隔符的，这里补充一个; 用sort排序 uniq 去重 cypath换win字符 tr去换行
  # 有换行时path全部不识别，只有powershell能识别，神奇
  winENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
  #cygpath 是 msys带的处理路径的工具
  echo $winENV
  powershell -C "[environment]::SetEnvironmentvariable('path', \"$winENV\", [System.EnvironmentVariableTarget]::User)"
  setx test_env "$winENV"
  #powershell -C "[environment]::SetEnvironmentvariable('path', \"$winENV\", [System.EnvironmentVariableTarget]::Machine)"
  #这样设置后的环境变量莫名其妙不能用 ,可能由于回车没去掉
fi
