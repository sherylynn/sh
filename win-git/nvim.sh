#!/bin/bash
INSTALL_PATH=$HOME/tools
NVIM_HOME=$INSTALL_PATH/nvim
NVIM_ROOT=$NVIM_HOME/Neovim
NVIM_ROOT_BIN=$NVIM_ROOT/bin
NVIM_VERSION=0.3.4
NVIM_ARCH=64
#NVIM_ARCH=arm64
#NVIM_ARCH=armv6l
#arm64

# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
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
  NVIM_ARCH=64
elif [[ "$(uname -a)" == *i686* ]]; then
  NVIM_ARCH=32
elif [[ "$(uname -a)" == *armv8l* ]]; then
  NVIM_ARCH=arm64
elif [[ "$(uname -a)" == *aarch64* ]]; then
  NVIM_ARCH=arm64
fi
while getopts 'v:a:sc' OPT; do
  case $OPT in
    v)
      NVIM_VERSION="$OPTARG";;
    a)
      NVIM_ARCH="$OPTARG";;
    s)
      Server="y";;
    c)
      Client="y";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

NVIM_FILE_NAME=nvim-${PLATFORM}${NVIM_ARCH}
if [[ ${PLATFORM} == win ]]; then
  NVIM_FILE_PACK=${NVIM_FILE_NAME}.zip
else
  NVIM_FILE_PACK=${NVIM_FILE_NAME}.tar.gz
fi
# init pwd
cd $HOME

shift $(($OPTIND - 1))

if [[ "$(nvim --version)" != *NVIM*v${NVIM_VERSION}* ]]; then
  if [ ! -d "${INSTALL_PATH}" ]; then
    mkdir $INSTALL_PATH
  fi

  if [ ! -f "${NVIM_FILE_PACK}" ]; then
    Download_URL=https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/${NVIM_FILE_PACK}
    echo ${Download_URL}
    curl -o ${NVIM_FILE_PACK} -L ${Download_URL}
  fi
  
  if [ ! -d "${NVIM_FILE_NAME}" ]; then
    if [ ${PLATFORM} == win ]; then
      unzip -q ${NVIM_FILE_PACK} -d ${NVIM_FILE_NAME}
    else
      mkdir ${NVIM_FILE_NAME}
      tar -xzf ${NVIM_FILE_PACK} -C ${NVIM_FILE_NAME}
    fi
  fi
  rm -rf ${NVIM_HOME} && \
  mv ${NVIM_FILE_NAME} ${NVIM_HOME} && \
  rm -rf ${NVIM_FILE_PACK}
fi
#--------------new .toolsrc-----------------------
if [[ "$(cat ${BASH_FILE})" != *nvimrc* ]]; then
  echo 'test -f ~/.nvimrc&& . ~/.nvimrc' >> ${BASH_FILE}
fi

export XDG_CONFIG_HOME=$HOME/.config
export PATH=$PATH:${NVIM_ROOT_BIN}

echo 'export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}>~/.nvimrc
echo 'export PATH=$PATH:'${NVIM_ROOT_BIN}>>~/.nvimrc

#  ----windows bat----
if [[ $SYSTEM == 1 ]]; then
if [[ $PLATFORM == windows ]]; then
  setx XDG_CONFIG_HOME $(cygpath -w ${XDG_CONFIG_HOME})
  windowsENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
  echo $windowsENV
  setx Path "$windowsENV"
fi
fi
