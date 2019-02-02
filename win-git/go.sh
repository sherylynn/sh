#!/bin/bash
lynn=$HOME
GO_VERSION=1.11
GO_ARCH=amd64
#GO_ARCH=arm64
#GO_ARCH=armv6l
#arm64
cd $HOME
if [ ! -d "$HOME/tools" ]; then
  mkdir $HOME/tools
fi
while getopts 'v:a:sc' OPT; do
  case $OPT in
    v)
      GO_VERSION="$OPTARG";;
    a)
      GO_ARCH="$OPTARG";;
    s)
      Server="y";;
    c)
      Client="y";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

shift $(($OPTIND - 1))

wget https://dl.google.com/go/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz && \
  tar -C $HOME/tools -xzf go${GO_VERSION}.linux-${GO_ARCH}.tar.gz && \
  rm go${GO_VERSION}.linux-${GO_ARCH}.tar.gz
echo 'export GOROOT=$HOME/tools/go'>>~/.bashrc
echo 'export PATH=$PATH:$GOROOT/bin'>>~/.bashrc
echo 'export PATH=$PATH:$HOME/go/bin'>>~/.bashrc
