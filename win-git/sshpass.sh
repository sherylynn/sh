#!/bin/bash
. $(dirname "$0")/toolsinit.sh
NAME=sshpass
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
CMD="sshpass -p 'YOURPASSWD' ssh your_id@your_ip"

# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
PLATFORM=$(platform)
if [[ $(platform) == *linux* ]]; then
  apt install sshpass -y
  echo 'alias sss="'$CMD'" '>${TOOLSRC}
fi
if [[ $(platform) == *win* ]]; then
  case $(arch) in 
    amd64) SOFT_ARCH=64;;
    386) SOFT_ARCH=32;;
  esac
fi
