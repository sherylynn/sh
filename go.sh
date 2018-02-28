#!/bin/bash
lynn=$HOME
GO_VERSION=1.10
GO_ARCH=amd64
cd $HOME
if [ ! -d "$HOME/tools" ]; then
  mkdir $HOME/tools
fi
wget https://dl.google.com/go/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz && \
  tar -C $HOME/tools -xzf go${GO_VERSION}.linux-${GO_ARCH}.tar.gz && \
  rm go${GO_VERSION}.linux-${GO_ARCH}.tar.gz
echo 'export GOROOT=$HOME/tools/go'>>~/.bashrc
echo 'export PATH=$PATH:$GOROOT/bin'>>~/.bashrc
