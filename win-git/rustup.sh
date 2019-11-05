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
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
tee $TOOLSRC <<EOF
export RUSTUP_HOME=${RUSTUP_HOME}
export CARGO_HOME=${CARGO_HOME}
source ${CARGO_HOME}/env
export CARGO_REGISTRIES_MY_REGISTRY_INDEX=http://mirrors.ustc.edu.cn/crates.io-index
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
EOF
tee $CARGO_HOME/config <<EOF
[source.crates-io]
registry = "https://github.com/rust-lang/crates.io-index"
replace-with = 'ustc'
[source.ustc]
registry = "git://mirrors.ustc.edu.cn/crates.io-index"
EOF
curl https://sh.rustup.rs -sSf | sh -s -- --default-toolchain stable

