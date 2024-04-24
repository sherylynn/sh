#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
NAME=gcc
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})

if [[ $(platform) == *mac* ]]; then
tee  ${TOOLSRC} <<EOF
export CC=/usr/local/bin/gcc-13
export CXX=/usr/local/bin/g++-13
alias cc='gcc-13'
alias gcc='gcc-13'
alias c++='c++-13'
alias g++='g++-13'
EOF
#你真正需要的是重置一下
sudo sudo xcode-select --reset
fi
