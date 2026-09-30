#!/bin/bash
set -Ee -o pipefail
# source
#------------------init function----------------
. "$(dirname "$0")/toolsinit.sh"
#------------------win function-----------------
. "$(dirname "$0")/winPath.sh"
#-----------------------------------------------
INSTALL_PATH=$HOME/tools

TOOLSRC_NAME=rustrc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)
PLATFORM=$(platform)
RUSTUP_HOME=$INSTALL_PATH/rustup
CARGO_HOME=$INSTALL_PATH/cargo

mkdir -p "$RUSTUP_HOME"
mkdir -p "$CARGO_HOME"

export RUSTUP_HOME=$RUSTUP_HOME
export CARGO_HOME=$CARGO_HOME
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
tee "$TOOLSRC" >/dev/null <<EOF
export RUSTUP_HOME=${RUSTUP_HOME}
export CARGO_HOME=${CARGO_HOME}
source ${CARGO_HOME}/env
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
EOF
tee "$CARGO_HOME/config.toml" >/dev/null <<EOF
[source.crates-io]
replace-with = 'ustc'
[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
EOF

if [[ ! -x "$CARGO_HOME/bin/rustup" ]]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable
fi

# Always move the local stable toolchain to the newest stable release available
# from the configured dist server. Disable rustup's own auto-update here: on some
# chroot/container filesystems replacing the running rustup binary fails with
# ETXTBSY (Text file busy), while the Rust toolchain itself updates normally.
"$CARGO_HOME/bin/rustup" set auto-self-update disable
"$CARGO_HOME/bin/rustup" update stable
"$CARGO_HOME/bin/rustup" default stable
"$CARGO_HOME/bin/rustup" component add rustfmt clippy --toolchain stable

source "$CARGO_HOME/env"
printf 'rustup: '; rustup --version
printf 'rustc:  '; rustc --version
printf 'cargo:  '; cargo --version
printf 'clippy: '; cargo clippy --version
printf 'fmt:    '; rustfmt --version

