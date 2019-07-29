#!/bin/bash
INSTALL_PATH=$HOME/tools
SOFT_HOME=$INSTALL_PATH/apktool
#LIBS_HOME=$INSTALL_PATH/lua
LIBS_VERSION=2.4.0
DEX_VERSION=2.0
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=apktoolrc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
if [[ "$(uname)" =~ (MINGW)|(MSYS) ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=windows
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
  PLATFORM=linux
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=osx
fi

BIN_FILE_NAME=apktool
if [[ ${PLATFORM} == windows ]]; then
  BIN_FILE_PACK=${BIN_FILE_NAME}.bat
else
  BIN_FILE_PACK=${BIN_FILE_NAME}
fi

LIBS_FILE_NAME=${BIN_FILE_NAME}_${LIBS_VERSION}
LIBS_FILE_PACK=${LIBS_FILE_NAME}.jar

DEX_FILE_NAME=dex2jar
DEX_FILE_PACK=${DEX_FILE_NAME}-${DEX_VERSION}.zip
DEX_HOME=${INSTALL_PATH}/${DEX_FILE_NAME}
#--------------------------
# Install LIBS
#--------------------------
if [ ! -d "${SOFT_HOME}" ]; then
  mkdir -p ${SOFT_HOME}
fi

if ! command -v apktool && ! command -v apktool.bat ;then
  if [ ! -d "${INSTALL_PATH}" ]; then
    mkdir $INSTALL_PATH
  fi

  if [ ! -f "${BIN_FILE_PACK}" ]; then
    echo https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/${PLATFORM}/${BIN_FILE_PACK}
    curl -o ${BIN_FILE_PACK} -L https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/${PLATFORM}/${BIN_FILE_PACK}
  fi
  
  if [ ! -f "${LIBS_FILE_PACK}" ]; then
    curl -o ${LIBS_FILE_PACK} -L https://github.com/iBotPeaches/Apktool/releases/latest/download/${LIBS_FILE_PACK}
  fi

  if [ ! -f "${BIN_FILE_NAME}.jar" ]; then
    mv ${LIBS_FILE_PACK} ${BIN_FILE_NAME}.jar
  fi

  mv ${BIN_FILE_PACK} $SOFT_HOME/${BIN_FILE_PACK} && \
  mv ${BIN_FILE_NAME}.jar $SOFT_HOME/${BIN_FILE_NAME}.jar

fi
if ! command -v d2j-dex2jar && ! command -v d2j-dex2jar.bat ;then
  if [ ! -f "${DEX_FILE_PACK}" ]; then
    curl -o ${DEX_FILE_PACK} -L https://sourceforge.net/projects/dex2jar/files/${DEX_FILE_PACK}/download
  fi

  if [ ! -d "${DEX_FILE_NAME}" ]; then
      #unzip -q ${DEX_FILE_PACK} -d ${DEX_FILE_NAME}
      unzip -q ${DEX_FILE_PACK}
      mv ${DEX_FILE_NAME}-${DEX_VERSION} ${DEX_FILE_NAME}
  fi
  rm -rf ${DEX_HOME} && \
  mv ${DEX_FILE_NAME} ${DEX_HOME} && \
  rm -rf ${DEX_FILE_PACK}
fi
#--------------------------
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi

echo "export PATH=$SOFT_HOME:"'$PATH'> $TOOLSRC
echo "export PATH=$DEX_HOME:"'$PATH'>>$TOOLSRC
