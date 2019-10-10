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
  if [[ "$(cat ${BASH_FILE})" != *${toolsrc_name}* ]]; then
    echo "test -f ${toolsrc} && . ${toolsrc}" >> ${BASH_FILE}
  fi
  echo $toolsrc
}

