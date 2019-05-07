# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
INSTALL_PATH=$HOME/tools
BASH_DIR=$INSTALL_PATH/rc
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

platform(){
  echo $PLATFORM
}

toolsRC(){
  local toolsrc_name=$1
  local toolsrc=$BASH_DIR/${toolsrc_name}
  #--------------new .toolsrc-----------------------
  if [ ! -d "${BASH_DIR}" ]; then
    mkdir $BASH_DIR
  fi
  if [[ "$(cat ${BASH_FILE})" != *${toolsrc_name}* ]]; then
    echo "test -f ${toolsrc} && . ${toolsrc}" >> ${BASH_FILE}
  fi
  echo $toolsrc
}

