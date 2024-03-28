#!/bin/bash
INSTALL_PATH=$HOME/tools
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=vimcoderc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
if [[ "$(uname)" == *MINGW* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=win
elif [[ "$(uname)" == *Linux* ]]; then
  BASH_FILE=~/.bashrc
  PLATFORM=linux
elif [[ "$(uname)" == *Darwin* ]]; then
  BASH_FILE=~/.bash_profile
  PLATFORM=macos
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
#nvim in windows
if [[ $PLATFORM =~ (win) ]]; then
  echo let g:VIMHOME=\"vimcode\" > $XDG_CONFIG_HOME/nvim/init.vim
  echo 'source '$(cygpath -w ${XDG_CONFIG_HOME}/config/vimrc) >> $XDG_CONFIG_HOME/nvim/init.vim
fi

#if [[ $PLATFORM =~ (macos) ]]; then
  mkdir $HOME/.config/nvim
  echo "set runtimepath^=~/.vim runtimepath+=~/.vim/after"> $HOME/.config/nvim/init.vim
  echo "let &packpath = &runtimepath">> $HOME/.config/nvim/init.vim
  echo "source ~/.vimrc">> $HOME/.config/nvim/init.vim
  echo "source ~/vimcode/config/org.vim" >> $HOME/.config/nvim/init.vim
#fi

mkdir autoload
cd autoload
if [ ! -f plug.vim ]; then
  curl -fLo plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi
