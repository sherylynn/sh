#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=Genymobile
NAME=scrcpy
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
#SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
#SOFT_VERSION=v2.7
SOFT_VERSION=v3.3.1
#SOFT_VERSION=v3.0
#SOFT_VERSION=v3.0.2
#都很卡，离谱了
#2.7 的居然没有预编译的版本可以下载，离谱
echo "soft version is $SOFT_VERSION"
SOFT_ARCH=64

# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
PLATFORM=$(platform)
if [[ $(platform) == *mac* ]]; then
  case $(arch) in
    amd64) SOFT_ARCH=x86_64 ;;
    aarch64) SOFT_ARCH=aarch64 ;;
    386) SOFT_ARCH=32 ;;
  esac
  if [[ $SOFT_VERSION == *3.0* ]]; then
    SOFT_FILE_NAME=${NAME}-${PLATFORM}-${SOFT_ARCH}-${SOFT_VERSION}
    #action 自动打包有问题，其实没有用 gzip 压缩，手动修改一下
    SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
    SOFT_FILE_PACK_TAR=${SOFT_FILE_NAME}.tar
    # init pwd
    cd $HOME

    SOFT_URL=https://github.com/Genymobile/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}
    #if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
    if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
      $(cache_downloader $SOFT_FILE_PACK_TAR $SOFT_URL)
      $(cache_unpacker $SOFT_FILE_PACK_TAR $SOFT_FILE_NAME)

      rm -rf ${SOFT_HOME} &&
        mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}
    fi
    #--------------new .toolsrc-----------------------
    export PATH=$PATH:${SOFT_HOME}/${SOFT_FILE_NAME}

    echo 'export PATH=$PATH:'${SOFT_HOME}/${SOFT_FILE_NAME} >${TOOLSRC}
  else
    #build
    # runtime dependencies
    brew install sdl2 ffmpeg libusb

    # client build dependencies
    brew install pkg-config meson

    cd $(install_path)
    git clone https://github.com/${AUTHOR}/${NAME} $SOFT_HOME
    cd $SOFT_HOME
    git pull
    git checkout $SOFT_VERSION
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
    sudo ninja -Cx install
    #echo 'alias scrcpy="'${SOFT_HOME}/run ${SOFT_HOME}/x'"' >${TOOLSRC}
  fi
fi
if [[ $(platform) == *linux* ]]; then
  case $(arch) in
    amd64) SOFT_ARCH=x86_64 ;;
    aarch64) SOFT_ARCH=arm ;;
    386) SOFT_ARCH=32 ;;
  esac

  if [[ $SOFT_ARCH == *64* ]] && [[ "$(uname -a)" != *KYLINOS* ]] && [[ $test_command == "还是不要直接下载，全部编译" ]]; then
    SOFT_FILE_NAME=${NAME}-${PLATFORM}-${SOFT_ARCH}-${SOFT_VERSION}
    #action 自动打包有问题，其实没有用 gzip 压缩，手动修改一下
    SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
    SOFT_FILE_PACK_TAR=${SOFT_FILE_NAME}.tar
    # init pwd
    cd $HOME

    SOFT_URL=https://github.com/Genymobile/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}
    #if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
    if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
      $(cache_downloader $SOFT_FILE_PACK_TAR $SOFT_URL)
      $(cache_unpacker $SOFT_FILE_PACK_TAR $SOFT_FILE_NAME)

      rm -rf ${SOFT_HOME} &&
        mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}
    fi
    #--------------new .toolsrc-----------------------
    SOFT_ROOT=${SOFT_HOME}/${SOFT_FILE_NAME}
    #export PATH=$PATH:${SOFT_HOME}
    export PATH=$PATH:${SOFT_ROOT}

    echo 'export PATH=$PATH:'${SOFT_ROOT} >${TOOLSRC}
  else
    #deb apt# for Debian/Ubuntu
    sudo apt install -y ffmpeg libsdl2-2.0-0 adb wget gcc git pkg-config meson ninja-build ccache libsdl2-dev libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev libswresample-dev libusb-1.0-0 libusb-1.0-0-dev
    cd $(install_path)
    git clone https://github.com/${AUTHOR}/${NAME} $SOFT_HOME
    cd $SOFT_HOME
    git pull
    git checkout $SOFT_VERSION
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
    sudo ninja -Cx install
    #echo 'alias scrcpy="'${SOFT_HOME}/run ${SOFT_HOME}/x'"' >${TOOLSRC}
    #uninstall
    #sudo ninja -Cx uninstall
  fi
fi
if [[ $(platform) == *win* ]]; then
  case $(arch) in
    amd64) SOFT_ARCH=64 ;;
    386) SOFT_ARCH=32 ;;
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

    rm -rf ${SOFT_HOME} &&
      mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}
  fi
  #--------------new .toolsrc-----------------------
  export PATH=$PATH:${SOFT_HOME}

  echo 'export PATH=$PATH:'${SOFT_HOME} >${TOOLSRC}

  #  ----windows bat----
  if [[ $WIN_PATH ]]; then
    if [[ $PLATFORM == windows ]]; then
      windowsENV="$(echo -e ${PATH//:/;\\n}';' | sort | uniq | cygpath -w -f - | tr -d '\n')"
      echo $windowsENV
      setx Path "$windowsENV"
    fi
  fi
fi
