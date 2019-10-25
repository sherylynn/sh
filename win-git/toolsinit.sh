#!/bin/bash
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
INSTALL_PATH=$HOME/tools
if [ ! -d "${INSTALL_PATH}" ]; then
  mkdir -p $INSTALL_PATH
fi
CACHE_FOLDER=$INSTALL_PATH/cache
BASH_DIR=$INSTALL_PATH/rc
ZSH_FILE=$HOME/.zshrc
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

if [[ "$(uname -a)" == *x86_64* ]]; then
  ARCH=amd64
elif [[ "$(uname -a)" == *i686* ]]; then
  ARCH=386
elif [[ "$(uname -a)" == *armv8l* ]]; then
  case $(getconf LONG_BIT) in 
    32) ARCH=armhf;;
    64) ARCH=aarch64;;
  esac
elif [[ "$(uname -a)" == *aarch64* ]]; then
  case $(getconf LONG_BIT) in 
    32) ARCH=armhf;;
    64) ARCH=aarch64;;
  esac
elif [[ "$(uname -a)" == *armv7l* ]]; then
  ARCH=armhf
fi

ALLTOOLSRC_FILE=$BASH_FILE
BASH_TYPE=bash
#zsh
if command -v zsh >/dev/null 2>&1; then
  ALLTOOLSRC_FILE=$BASH_DIR/allToolsrc
  if [[ "$(cat ${ZSH_FILE})" != *${ALLTOOLSRC_FILE}* ]]; then
    echo "test -f ${ALLTOOLSRC_FILE} && . ${ALLTOOLSRC_FILE}" >> ${ZSH_FILE}
  fi
  BASH_TYPE=zsh
fi

platform(){
  echo $PLATFORM
}

arch(){
  echo $ARCH
}

toolsRC(){
  local toolsrc_name=$1
  local toolsrc=$BASH_DIR/${toolsrc_name}
  #--------------new .toolsrc-----------------------
  if [ ! -d "${BASH_DIR}" ]; then
    mkdir $BASH_DIR
  fi
  touch ${ALLTOOLSRC_FILE}
  if [[ "$(cat ${ALLTOOLSRC_FILE})" != *${toolsrc_name}* ]]; then
    echo not exist ${toolsrc}
  else
    sed -i '/'${toolsrc_name}'/d' ${ALLTOOLSRC_FILE}
  fi
  echo "test -f ${toolsrc} && . ${toolsrc}" >> ${ALLTOOLSRC_FILE}
  echo $toolsrc
}

bash_file(){
  echo $BASH_FILE
}

bash_type(){
  echo $BASH_TYPE
}

alltoolsrc_file(){
  echo $ALLTOOLSRC_FILE
}

install_path(){
  echo $INSTALL_PATH
}

cache_folder(){
  if [[ ! -d $CACHE_FOLDER ]]; then
    mkdir -p $CACHE_FOLDER
    echo $CACHE_FOLDER
  fi
}

cache_downloader(){
  local soft_file_pack=$1
  local soft_url=$2
  cd $CACHE_FOLDER
  if [[ ! -f $soft_file_pack ]]; then
    # use curl
    #curl -o $soft_file_pack $soft_url
    # use wget
    wget -O $soft_file_pack -c $soft_url
  fi
}

cache_unpacker(){
  local soft_file_pack=$1
  local soft_file_name=$2
  cd $CACHE_FOLDER
  if [ ! -d "${soft_file_name}" ]; then
    if [[ ${PLATFORM} == win ]]; then
      unzip -q ${soft_file_pack} -d ${soft_file_name}
    else
      mkdir ${soft_file_name}
      tar -xzf ${soft_file_pack} -C ${soft_file_name}
    fi
  fi

}
