#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=qhuyduong
NAME=adb
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
echo "soft version is $SOFT_VERSION"
SOFT_ARCH=64

# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
PLATFORM=$(platform)
if [[ $(platform) == *linux* ]]; then
  mkdir $SOFT_HOME
  #SOFT_URL=https://github.com/${AUTHOR}/${NAME}/releases/download/${SOFT_VERSION}/adb
  SOFT_URL=https://github.com/${AUTHOR}/arm_${NAME}/releases/download/v1.0.39-aarch64/${NAME}
  SOFT_FILE_NAME=${NAME}
  $(cache_downloader $SOFT_FILE_NAME $SOFT_URL)
  cp $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}/${NAME}
  chmod 777 ${SOFT_HOME}/${NAME}
  echo 'export PATH=$PATH:'${SOFT_HOME}>${TOOLSRC}
fi
if [[ $(platform) == *win* ]]; then
  case $(arch) in 
    amd64) SOFT_ARCH=64;;
    386) SOFT_ARCH=32;;
  esac

  SOFT_FILE_NAME=${NAME}-${PLATFORM}${SOFT_ARCH}-${SOFT_VERSION}
  SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
  # init pwd
  cd $HOME

  SOFT_URL=https://github.com/Genymobile/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}
  #if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
  if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
    $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
    $(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)
    
    rm -rf ${SOFT_HOME} && \
      mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME} 
  fi
  #--------------new .toolsrc-----------------------
  export PATH=$PATH:${SOFT_HOME}

  echo 'export PATH=$PATH:'${SOFT_HOME}>>${TOOLSRC}

  #  ----windows bat----
  if [[ $WIN_PATH  ]]; then
    if [[ $PLATFORM == windows ]]; then
      windowsENV="$(echo -e ${PATH//:/;\\n}';' |sort|uniq|cygpath -w -f -|tr -d '\n')"
      echo $windowsENV
      setx Path "$windowsENV"
    fi
  fi
fi
