#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
AUTHOR=microsoft
NAME=vscode
BIN_NAME=code
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
SOFT_ARCH=amd64
case $(platform) in
  macos) PLATFORM=macOS;;
  win) PLATFORM=Windows;;
  linux) PLATFORM=linux;;
esac

case $(arch) in 
  amd64) SOFT_ARCH=64-bit;;
  386) SOFT_ARCH=32-bit;;
  armhf) SOFT_ARCH=ARM_v6;;
  aarch64) SOFT_ARCH=arm64;;
esac


SOFT_FILE_NAME=${NAME}_${SOFT_VERSION}_${PLATFORM}_${SOFT_ARCH}
# init pwd
cd $HOME
SOFT_URL="https://code.visualstudio.com/sha/download?build=stable&os=${PLATFORM}-deb-${SOFT_ARCH}"

if [[ "$(${BIN_NAME} -v)" != *${SOFT_VERSION}* ]]; then
  $(cache_downloader $SOFT_FILE_NAME $SOFT_URL)
  
  sudo dpkg -i $(cache_folder)/${SOFT_FILE_NAME}
  sudo apt install -f

fi
mkdir -p $SOFT_HOME
echo "alias code='code --no-sandbox --user-data-dir "$SOFT_HOME"'">${TOOLSRC}
