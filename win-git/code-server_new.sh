#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=cdr
NAME=code-server
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
echo "soft version is $SOFT_VERSION"

case $(arch) in 
  amd64) SOFT_ARCH=amd64;;
  386) SOFT_ARCH=386;;
  armhf) SOFT_ARCH=armv6l;;
  aarch64) SOFT_ARCH=arm64;;
esac
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
PLATFORM=$(platform)

SOFT_FILE_NAME=${NAME}_$(version_without_prefix_v $SOFT_VERSION)_${SOFT_ARCH}
echo ${SOFT_FILE_NAME}
SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME deb)

SOFT_URL=https://github.com/${AUTHOR}/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}
if [[ $(platform) == *linux* ]]; then
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  sudo dpkg -i $(cache_folder)/$SOFT_FILE_PACK
  #sudo systemctl daemon-reload
  #sudo systemctl enable code-server@$USER
  #sudo systemctl start code-server@$USER
  ./systemd_code-server.sh
fi
