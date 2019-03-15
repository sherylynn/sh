#!/bin/bash
INSTALL_PATH=$HOME/tools
SOFT_HOME=$INSTALL_PATH/zlua
LIBS_HOME=$INSTALL_PATH/lua
LIBS_VERSION=5.3.5
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=zluarc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
if [[ "$(uname)" == *MINGW* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=win
  LIBS_ARCH=Win32_bin
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
  PLATFORM=Linux
  LIBS_ARCH=Linux44_64_bin
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=MacOS
  LIBS_ARCH=MacOS1013_bin
fi

LIBS_FILE_NAME=lua-${LIBS_VERSION}_${LIBS_ARCH}
if [[ ${PLATFORM} == win ]]; then
  LIBS_FILE_PACK=${LIBS_FILE_NAME}.zip
else
  LIBS_FILE_PACK=${LIBS_FILE_NAME}.tar.xz
fi
#--------------------------
# Install LIBS
#--------------------------

if [ ! -d "${LIBS_HOME}" ]; then
  if [ ! -d "${INSTALL_PATH}" ]; then
    mkdir $INSTALL_PATH
  fi

  if [ ! -f "${LIBS_FILE_PACK}" ]; then
    curl -o ${LIBS_FILE_PACK} -L https://sourceforge.net/projects/luabinaries/files/${LIBS_VERSION}/Tools%20Executables/${LIBS_FILE_PACK}/download
  fi

  if [ ! -d "${LIBS_FILE_NAME}" ]; then
    if [[ ${PLATFORM} == win ]]; then
      unzip -q ${LIBS_FILE_PACK} -d ${LIBS_FILE_NAME}
    else
      mkdir ${SOFT_FILE_NAME}
      tar -xzf ${LIBS_FILE_PACK} -C ${LIBS_FILE_NAME}
    fi
  fi

  rm -rf $LIBS_HOME && \
  mv ${LIBS_FILE_NAME} $LIBS_HOME && \
  rm -rf ${LIBS_FILE_PACK}
fi
#--------------------------
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi
#eval '"$(lua '${SOFT_HOME}'/z.lua --init bash enhanced once echo fzf)"'
#export alias zc='z -c'
#export alias zz='z -i'
#export alias zf='z -I'
#export alias zb='z -b'
if [[ "$(uname -a)" =~ (x86_64)|(i686) ]]; then
  echo $LIBS_HOME
  echo "export PATH=$LIBS_HOME:$PATH" > $TOOLSRC
  echo 'eval "$(lua53 '${SOFT_HOME}'/z.lua --init bash enhanced once echo fzf)"' >> $TOOLSRC
else
  sudo apt install lua5.3 -y
  echo 'eval "$(lua '${SOFT_HOME}'/z.lua --init bash enhanced once echo fzf)"' > $TOOLSRC
fi
echo "alias zc='z -c'" >> $TOOLSRC
echo "alias zz='z -i'" >> $TOOLSRC
echo "alias zf='z -I'" >> $TOOLSRC
echo "alias zb='z -b'" >> $TOOLSRC
cd $INSTALL_PATH
git clone https://github.com/skywind3000/z.lua $SOFT_HOME
cd $SOFT_HOME
git pull
