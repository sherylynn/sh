#!/bin/bash
. $(dirname "$0")/toolsinit.sh
NAME=brew
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' > ${TOOLSRC}
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
