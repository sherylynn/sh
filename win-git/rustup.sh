#!/bin/bash
# source
#------------------init function----------------
. $(dirname "$0")/toolsinit.sh
#------------------win function-----------------
echo $(dirname "$0")/winPath.sh
. $(dirname "$0")/winPath.sh
#-----------------------------------------------
INSTALL_PATH=$HOME/tools

TOOLSRC_NAME=rustrc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)
PLATFORM=$(platform)
RUSTUP_HOME=$INSTALL_PATH/rustup
CARGO_HOME=$INSTALL_PATH/cargo

mkdir -p $RUSTUP_HOME
mkdir -p $CARGO_HOME

export RUSTUP_HOME=$RUSTUP_HOME
export CARGO_HOME=$CARGO_HOME
echo 'export RUSTUP_HOME='${RUSTUP_HOME}>$TOOLSRC
echo 'export CARGO_HOME='${CARGO_HOME}>>$TOOLSRC
curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain none