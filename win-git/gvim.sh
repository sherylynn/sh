#!/bin/bash
INSTALL_PATH=$HOME/tools
BASH_DIR=$INSTALL_PATH/rc
TOOLSRC_NAME=gvimrc
TOOLSRC=$BASH_DIR/${TOOLSRC_NAME}
GVIM_HOME=$INSTALL_PATH/gvim
GVIM_ROOT=$GVIM_HOME/vim
GVIM_ROOT_BIN=$GVIM_ROOT/vim81
GVIM_VERSION=8.1.0996
GVIM_ARCH=x64
#GVIM_ARCH=arm64
#GVIM_ARCH=armv6l
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
  GVIM_ARCH=x64
elif [[ "$(uname -a)" == *i686* ]]; then
  GVIM_ARCH=x86
elif [[ "$(uname -a)" == *armv8l* ]]; then
  GVIM_ARCH=arm64
elif [[ "$(uname -a)" == *aarch64* ]]; then
  GVIM_ARCH=arm64
fi
while getopts 'v:a:sc' OPT; do
  case $OPT in
    v)
      GVIM_VERSION="$OPTARG";;
    a)
      GVIM_ARCH="$OPTARG";;
    s)
      Server="y";;
    c)
      Client="y";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

GVIM_FILE_NAME=gvim_${GVIM_VERSION}_${GVIM_ARCH}
if [[ ${PLATFORM} == win ]]; then
  GVIM_FILE_PACK=${GVIM_FILE_NAME}.zip
else
  GVIM_FILE_PACK=${GVIM_FILE_NAME}.tar.gz
fi
# init pwd
cd $HOME

shift $(($OPTIND - 1))

if [[ "$(gvim --version)" != *GVIM*v${GVIM_VERSION}* ]]; then
  if [ ! -d "${INSTALL_PATH}" ]; then
    mkdir $INSTALL_PATH
  fi

  if [ ! -f "${GVIM_FILE_PACK}" ]; then
    Download_URL=https://github.com/vim/vim-win32-installer/releases/download/v${GVIM_VERSION}/${GVIM_FILE_PACK}
    echo ${Download_URL}
    curl -o ${GVIM_FILE_PACK} -L ${Download_URL}
  fi
  
  if [ ! -d "${GVIM_FILE_NAME}" ]; then
    if [ ${PLATFORM} == win ]; then
      unzip -q ${GVIM_FILE_PACK} -d ${GVIM_FILE_NAME}
    else
      mkdir ${GVIM_FILE_NAME}
      tar -xzf ${GVIM_FILE_PACK} -C ${GVIM_FILE_NAME}
    fi
  fi
  rm -rf ${GVIM_HOME} && \
  mv ${GVIM_FILE_NAME} ${GVIM_HOME} && \
  rm -rf ${GVIM_FILE_PACK}
fi
#--------------new .toolsrc-----------------------
if [ ! -d "${BASH_DIR}" ]; then
  mkdir $BASH_DIR
fi
if [[ "$(cat ${BASH_FILE})" != *${TOOLSRC_NAME}* ]]; then
  echo "test -f ${TOOLSRC} && . ${TOOLSRC}" >> ${BASH_FILE}
fi

export XDG_CONFIG_HOME=$HOME/.config
export PATH=$PATH:${GVIM_ROOT_BIN}

echo 'export XDG_CONFIG_HOME='${XDG_CONFIG_HOME}> ${TOOLSRC}
echo 'export PATH=$PATH:'${GVIM_ROOT_BIN}>> ${TOOLSRC}

#  ----windows bat----
if [[ $SYSTEM == 1 ]]; then
if [[ $PLATFORM == windows ]]; then
  setx XDG_CONFIG_HOME $(cygpath -w ${XDG_CONFIG_HOME})
  windowsENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
  echo $windowsENV
  setx Path "$windowsENV"
fi
fi
