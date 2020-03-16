#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=microsoft
NAME=vscode
BIN_NAME=code
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
SOFT_ARCH=amd64
Server=n
Client=n
Just_Install=n
#SOFT_ARCH=arm
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
case $(platform) in
  macos) PLATFORM=macOS;;
  win) PLATFORM=Windows;;
  linux) PLATFORM=linux;;
esac
case $(platform) in
  macos) DOWNLOAD_ID=620882;;
  win) DOWNLOAD_ID=850641;;
  linux) DOWNLOAD_ID=620884;;
esac

case $(arch) in 
  amd64) SOFT_ARCH=64-bit;;
  386) SOFT_ARCH=32-bit;;
  armhf) SOFT_ARCH=ARM_v6;;
  aarch64) SOFT_ARCH=ARM64;;
esac

while getopts 'v:a:sc' OPT; do
  case $OPT in
    v)
      SOFT_VERSION="$OPTARG";;
    a)
      SOFT_ARCH="$OPTARG";;
    s)
      Server="y";;
    c)
      Client="y";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

shift $(($OPTIND - 1))

SOFT_FILE_NAME=${NAME}_${SOFT_VERSION}_${PLATFORM}_${SOFT_ARCH}
echo $SOFT_FILE_NAME
SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME )
COMMAND_NAME=$SOFT_FILE_NAME
# init pwd
cd $HOME
SOFT_URL="https://go.microsoft.com/fwlink/?LinkID=${DOWNLOAD_ID}"

if [[ "$(${BIN_NAME} -v)" != *${SOFT_VERSION}* ]]; then
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  $(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)
  
  rm -rf ${SOFT_HOME} && \
    mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME} 
fi


case $(platform) in
  macos) SOFT_ROOT=${SOFT_HOME}/'Visual\ Studio\ Code.app/Contents/Resources/app/bin';;
  win) SOFT_ROOT=${SOFT_HOME};;
  linux) SOFT_ROOT=${SOFT_HOME}/VSCode-linux-x64/bin;;
esac

export PATH=$PATH:${SOFT_ROOT}
echo 'export PATH=$PATH:'${SOFT_ROOT}>${TOOLSRC}

echo "the settings.json path is\n"
echo "linux   : ~/.config/Code/User/settings.json \n"
echo "windows : ~/AppData/Roaming/Code/User \n"
