#!/bin/bash
#------------------init function----------------
. $(dirname "$0")/toolsinit.sh

INSTALL_PATH=$HOME/tools
SOFT_HOME=$INSTALL_PATH/zlua
TOOLSRC_NAME=zluarc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)

#--------------------------
# Install LIBS
#--------------------------

if ! command -v lua && ! command -v lua53 ;then
  if [ ! -d "${INSTALL_PATH}" ]; then
    mkdir $INSTALL_PATH
  fi

  if [[ $(platform) == *macos* ]]; then
    #brew install lua51
    brew install lua
  elif [[ $(platform) == *linux* ]]; then
    sudo apt install lua5.1 lua-filesystem -y
  elif [[ $(platform) == *win* ]]; then
  	pacman -Syu mingw64/mingw-w64-x86_64-lua
    #pacman -Sy lua5.1 
  fi

fi
#--------------------------

echo 'eval "$(lua '${SOFT_HOME}'/z.lua --init '$(bash_type)' enhanced once echo fzf)"' > $TOOLSRC
#echo "alias zc='z -c'" >> $TOOLSRC
echo "alias zz='z -i'" >> $TOOLSRC
#echo "alias zf='z -I'" >> $TOOLSRC
echo "alias zb='z -b'" >> $TOOLSRC
#echo "source $HOME/sh/win-git/openPath.sh" >> $TOOLSRC
echo "export ZLUALOAD=1" >> $TOOLSRC
cd $INSTALL_PATH
git clone https://github.com/skywind3000/z.lua $SOFT_HOME
cd $SOFT_HOME
git pull
