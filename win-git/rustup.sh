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
export CARGO_FORK_AUTO_UPDATE=0
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

# Replace rustup's stock Cargo proxy with huacnlee/cargo.  The fork keeps
# Cargo's CLI/toolchain behavior while sharing build units across worktrees
# and projects and garbage-collecting old target data.  Keep upgrades owned
# by this bootstrap script rather than the fork's background daily updater so
# developer machines only change toolchains when rustup.sh is run explicitly.
export CARGO_FORK_AUTO_UPDATE=0
if [[ "$(cargo --version 2>/dev/null || true)" != *"huacnlee/cargo"* ]]; then
  curl --proto '=https' --tlsv1.2 -fsSL https://huacnlee.github.io/cargo/install.sh | sh
fi
if ! cargo --version | grep -q 'huacnlee/cargo'; then
  echo "failed to activate huacnlee/cargo" >&2
  exit 1
fi
printf 'rustup: '; rustup --version
printf 'rustc:  '; rustc --version
printf 'cargo:  '; cargo --version
printf 'clippy: '; cargo clippy --version
printf 'fmt:    '; rustfmt --version

