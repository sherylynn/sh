#!/bin/bash
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
PIP_USERBASE=$INSTALL_PATH/python-pip
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
# windows 下pip user时候的bin也不一样，不在 --user-base下 ,或者说
# bin即script的位置会随着bash执行时候的位置改变，如在~
# 下，会安装到 ~/users/lynn/,而不是C://users/lynn
# 此时除非在c盘根目录不然无法正确执行
# 如果手动设置pythonuserbase为反斜杠路径，就可以正常运行
# 这里取巧用单引号中不解释反斜杠来执行
# linux下 PIP_PATH=$(python -m site --user-base)"/bin"
# win下
export PATH=$PATH:${PYTHON_HOME}
export PYTHONUSERBASE=$USERPROFILE\\tools\\python-pip
python -m site
#-----------pip install path-----------------------------------
if [ ! -d "${PIP_USERBASE}" ]; then
  mkdir ${PIP_USERBASE}
fi
<<readme
--------------确保后续代码可以执行需要先删除------------
调试时候适合用<<的注释来屏蔽代码查看效果
类似run_module_ 的错误一般是路径问题，就是下述没删除的
readme
cd $INSTALL_PATH/python
mv python*._pth python._pth.save
#---------------------------------------------  需要有路径不然没user-site
python -m site --user-site
# userbase 变量需要在 python -m site 前
PIP_BIN_PATH=$(python -m site --user-site)
echo show_PIP_PATH:$PIP_BIN_PATH
export PATH=$PATH:${PYTHON_SCRIPTS}
export PATH=$PATH:'$PIP_BIN_PATH\\..\\Scripts'
export PYTHONPATH=${PYTHON_HOME}:${PYTHON_LIB}:${PYTHON_PACKAGES}
echo 'export PATH=$PATH:'${PYTHON_HOME}>~/.pythonrc
echo 'export PATH=$PATH:'${PYTHON_SCRIPTS}>>~/.pythonrc
echo 'export PATH=$PATH:'"'"$PIP_BIN_PATH\\..\\Scripts"'">>~/.pythonrc
echo 'export PYTHONPATH='${PYTHON_HOME}:${PYTHON_LIB}:${PYTHON_PACKAGES}>>~/.pythonrc
echo "export PYTHONUSERBASE="'$USERPROFILE\\tools\\python-pip'>>~/.pythonrc

#-------get pip-------------------------------------------
if [ ! -f "${GET_PIP_PATH}" ]; then
  curl -o ${GET_PIP} https://bootstrap.pypa.io/get-pip.py
fi
python ${GET_PIP} --user
