#!/bin/bash
INSTALL_PATH=$HOME/tools
SOFT_HOME=$INSTALL_PATH/lualib
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=lualibrc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
SOFT_VERSION=5.3.5
if [[ "$(uname)" =~ (MINGW)|(MSYS) ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=win
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
  PLATFORM=Linux
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=MacOS
fi
SOFT_FILE_NAME=lua-${SOFT_VERSION}
SOFT_FILE_PACK=${SOFT_FILE_NAME}.tar.gz
cd ~
if [ ! -f ${SOFT_FILE_PACK} ];then
  curl -o ${SOFT_FILE_PACK} -L http://www.lua.org/ftp/${SOFT_FILE_PACK}
fi
mkdir -p ${SOFT_FILE_NAME}
tar -xzf ${SOFT_FILE_PACK} -C ${SOFT_FILE_NAME}
cd ${SOFT_FILE_NAME}/${SOFT_FILE_NAME}
make clean
#make mingw
make posix
cp -R src ~/tools/lualib
#--------------------------
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi
echo "export PATH=$SOFT_HOME:"'$PATH'> $TOOLSRC
