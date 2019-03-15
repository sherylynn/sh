#!/bin/bash
INSTALL_PATH=$HOME/tools
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=vimcoderc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
if [[ "$(uname)" == *MINGW* ]]; then
  BASH_FILE=~/.bash_profile
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
fi
if [ ! -d "${BASH_DIR}" ]; then
  mkdir -p $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi
export XDG_CONFIG_HOME=$HOME/vimcode
echo 'export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}>${TOOLSRC}
cd ~
git clone https://github.com/sherylynn/vimcode $XDG_CONFIG_HOME
cd $XDG_CONFIG_HOME
echo let g:VIMHOME=\"vimcode\" > $HOME/.vimrc
echo 'source '$XDG_CONFIG_HOME'/config/vimrc' >> $HOME/.vimrc
#guifont和后面的内容不能有空格
#echo set guifont=Courier_new:h15:b >> ../.vimrc
echo set ff=unix >> $HOME/.vimrc
cp $HOME/.vimrc $XDG_CONFIG_HOME/nvim/init.vim

mkdir autoload
cd autoload
if [! -f plug.vim]; then
  curl -fLo plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi
