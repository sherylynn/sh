#!/bin/bash
# source
INSTALL_PATH=$HOME/tools
PYTHON_HOME=$INSTALL_PATH/python
PYTHON_VERSION=3.6.8
PYTHON_SHOTVERSION=${PYTHON_VERSION//./}
PYTHON_PREFIX=${PYTHON_SHOTVERSION:0:2}
PYTHON_LIB=$PYTHON_HOME/Lib
PYTHON_ZIP=$PYTHONHOME/python${PYTHON_PREFIX}.zip
PYTHON_PACKAGES=$PYTHON_LIB/site-packages
PYTHON_SCRIPTS=$PYTHON_HOME/Scripts
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
if [ "$(cat ~/.bash_profile)" == "*pythonrc*" ]; then
  echo 'test -f ~/.pythonrc && . ~/.pythonrc' >> ~/.bash_profile
fi
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
export PYTHONPATH=${PYTHON_HOME}:${PYTHON_LIB}:${PYTHON_PACKAGES}:${PYTHON_ZIP}:${PIP_BIN_PATH}
echo 'export PATH=$PATH:'${PYTHON_HOME}>~/.pythonrc
echo 'export PATH=$PATH:'${PYTHON_SCRIPTS}>>~/.pythonrc
echo 'export PATH=$PATH:'"'"$PIP_BIN_PATH\\..\\Scripts"'">>~/.pythonrc
echo 'export PYTHONPATH='${PYTHON_HOME}:${PYTHON_LIB}:${PYTHON_PACKAGES}:${PYTHON_ZIP}:${PIP_BIN_PATH}>>~/.pythonrc
echo "export PYTHONUSERBASE="'$USERPROFILE\\tools\\python-pip'>>~/.pythonrc

#-------get pip-------------------------------------------
if [ ! -f "${GET_PIP_PATH}" ]; then
  curl -o ${GET_PIP} https://bootstrap.pypa.io/get-pip.py
fi
echo Install pip
if [ "$(pip --version)" == "*from*" ]; then
  python ${GET_PIP} --user
fi

#  ----windows bat----
winPath(){
  #return ${1////\\}
  # shell 函数只能返回整数
  local x=$1
  local x_drive=${x///c/C:}
  local x_backsplash=${x_drive////\\}
  local x_semicolon=${x_backsplash//:/;}
  local x_c=${x_semicolon//C;/C:}
  echo $x_c
}
setx PYTHONHOME $USERPROFILE\\tools\\python
#setx PYTHONPATH '%PYTHONHOME%;%PYTHONHOME%\Lib;%PYTHONHOME%\site-packages;%PYTHONHOME%\python36.zip'
setx PYTHONPATH $(winPath ${PYTHONPATH})
setx PYTHONUSERBASE $USERPROFILE\\tools\\python-pip
setx PYTHON_BIN $(winPath ${PYTHON_HOME})";"$(winPath ${PYTHON_SCRIPTS})";"$(winPath ${PIP_BIN_PATH}/../Scripts)
#  没法setx path 因为git bash 中的path是冒号间隔的
# setx PATH ${PATH//:/;}
#cmd //c setx PATH %PATH%;test
start cmd '/k setx test_env "%PATH%"'
echo $(dirname "$0")
start $(cd $(dirname "$0");pwd)/setPath.bat
# git bash 中获取的 python是已经变态了的path,首先不能正常使用
# ~PATH~不能对path自己使用
# cmd "/c setx PATH ~PATH~;test"
# setx test_env "$(cmd //c echo %PATH%)"
# setx有一个1024数字的截断问题，没法解决
# setx PATH '%PATH%;%PYTHONHOME%;'${PYTHON_SCRIPTS};$PIP_BIN_PATH\\..\\Scripts
