#!/bin/bash
. $(dirname "$0")/toolsinit.sh
NAME=wechat
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

SOFT_VERSION=0.16.0
SOFT_ARCH=amd64
Server=n
Client=n
Just_Install=n
#SOFT_ARCH=arm
# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
PLATFORM=$(platform)
if [[ "$PLATFORM" == "macos" ]]; then
  PLATFORM=darwin
elif [[ "$PLATFORM" == "win" ]];then
  PLATFORM=windows
elif [[ "$PLATFORM" == "linux" ]];then
  PLATFORM=linux
fi

case $(arch) in 
  amd64) SOFT_ARCH=amd64;;
  386) SOFT_ARCH=386;;
  armhf) SOFT_ARCH=armv7;;
  aarch64) SOFT_ARCH=armv8;;
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

# init pwd
cd $HOME
SOFT_URL=https://github.com/cytle/wechat_web_devtools
$(git_downloader $SOFT_HOME $SOFT_URL)

# deps
if [[ ${PLATFORM} == linux ]]; then
  sudo apt-get install wine-binfmt
  sudo update-binfmts --import /usr/share/binfmts/wine
  sudo dpkg --add-architecture i386 \
    && sudo apt update \
    && sudo apt install wine32

fi

SOFT_ROOT=${SOFT_HOME}/bin

echo 'export PATH=$PATH:'${SOFT_ROOT} > ${TOOLSRC}
