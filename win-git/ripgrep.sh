#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=BurntSushi
NAME=ripgrep
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
echo "soft version is $SOFT_VERSION"
SOFT_ARCH=x86_64

# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
PLATFORM=$(platform)
if [[ $(platform) == *linux* ]]; then
  #deb apt
  sudo apt install -y ffmpeg libsdl2-2.0-0 adb wget \
                 gcc git pkg-config meson ninja-build libsdl2-dev \
                 libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev \
                 libusb-1.0-0 libusb-1.0-0-dev
  cd $(install_path)
  git clone https://github.com/${AUTHOR}/${NAME} $SOFT_HOME
  cd $SOFT_HOME
  git pull
  #prebuilt server
  SOFT_URL=https://github.com/Genymobile/${NAME}/releases/download/${SOFT_VERSION}/${NAME}-server-${SOFT_VERSION}
  SOFT_FILE_NAME=${NAME}-server-${SOFT_VERSION}
  $(cache_downloader $SOFT_FILE_NAME $SOFT_URL)
  cp $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}/
  #build
  meson x --buildtype release --strip -Db_lto=true \
      -Dprebuilt_server=${SOFT_FILE_NAME}
  ninja -Cx
  #install
  #sudo ninja -Cx install
  echo 'alias scrcpy="'${SOFT_HOME}/run ${SOFT_HOME}/x'"'>${TOOLSRC}
fi
if [[ $(platform) == *win* ]]; then
  PLATFORM=windows
  case $(arch) in 
    amd64) SOFT_ARCH=x86_64;;
    386) SOFT_ARCH=i686;;
  esac

  SOFT_FILE_NAME=${NAME}-${SOFT_VERSION}-${SOFT_ARCH}-pc-${PLATFORM}-gnu
  SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
  # init pwd
  cd $HOME

  SOFT_URL=https://github.com/${AUTHOR}/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}
  #if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
  if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
    $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
    $(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)
    
    rm -rf ${SOFT_HOME} && \
      mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME} 
  fi
  #--------------new .toolsrc-----------------------
  SOFT_ROOT=${SOFT_HOME}/${SOFT_FILE_NAME}
  export PATH=$PATH:${SOFT_ROOT}

  echo 'export PATH=$PATH:'${SOFT_ROOT}>${TOOLSRC}
fi
