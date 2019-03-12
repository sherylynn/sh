#!/bin/bash
INSTALL_PATH=$HOME/tools
zluaHOME=$INSTALL_PATH/zlua
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=zluarc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
if [[ "$(uname)" == *MINGW* ]]; then
  BASH_FILE=~/.bash_profile
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
fi
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi
echo 'eval "$(lua '${zluaHOME}'/z.lua --init bash enhanced once echo fzf)"' > $TOOLSRC
echo "alias zc='z -c'" >> $TOOLSRC
echo "alias zz='z -i'" >> $TOOLSRC
echo "alias zf='z -I'" >> $TOOLSRC
echo "alias zb='z -b'" >> $TOOLSRC
cd $INSTALL_PATH
git clone https://github.com/skywind3000/z.lua $zluaHOME
cd $zluaHOME
git pull
