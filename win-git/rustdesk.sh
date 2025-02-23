#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=rustdesk
NAME=rustdesk
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
echo "soft version is $SOFT_VERSION"

case $(arch) in
  amd64) SOFT_ARCH=x86_64 ;;
  386) SOFT_ARCH=386 ;;
  armhf) SOFT_ARCH=armhf ;;
  aarch64) SOFT_ARCH=aarch64 ;;
esac
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
PLATFORM=$(platform)
#截取掉字符串版本号的v
SOFT_FILE_NAME=${NAME}-${SOFT_VERSION}-${SOFT_ARCH}
SOFT_FILE_PACK=${SOFT_FILE_NAME}.deb

SOFT_URL=https://github.com/${AUTHOR}/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}
if [[ $(platform) == *linux* ]]; then
  $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
  #sudo apt install -y $(cache_folder)/$SOFT_FILE_PACK
  sudo dpkg -i $(cache_folder)/$SOFT_FILE_PACK
  sudo apt install -f -y
  #rm -rf ${SOFT_HOME} && mkdir -p ${SOFT_HOME}
  #cp $(cache_folder)/${SOFT_FILE_PACK} ${SOFT_HOME}/${SOFT_FILE_NAME}
  #chmod 777 ${SOFT_HOME}/${SOFT_FILE_NAME}
  #echo "export PATH=$SOFT_HOME:"'$PATH' > ${TOOLSRC}

  #./systemd_ttyd.sh
fi
