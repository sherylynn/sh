#!/bin/bash
set -euo pipefail

# Install/update apt-fast and tune it for NewHome mobile/chroot networking.
# apt update itself still uses normal APT; apt-fast accelerates package payloads
# for install/upgrade/full-upgrade by downloading them through aria2.

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

APT_FAST_REPO=${APT_FAST_REPO:-https://github.com/ilikenwf/apt-fast.git}
APT_FAST_BRANCH=${APT_FAST_BRANCH:-master}
APT_FAST_HOME=${APT_FAST_HOME:-/opt/apt-fast}
APT_FAST_BIN=${APT_FAST_BIN:-/usr/local/sbin/apt-fast}
APT_FAST_CONF=${APT_FAST_CONF:-/etc/apt-fast.conf}
APT_NETWORK_CONF=${APT_NETWORK_CONF:-/etc/apt/apt.conf.d/99newhome-network}

# Conservative defaults for a phone hotspot / proxy / ADB-forward style network.
# They still provide parallelism without opening dozens of simultaneous sockets.
APT_FAST_MAXNUM=${APT_FAST_MAXNUM:-8}
APT_FAST_MAXCONPERSRV=${APT_FAST_MAXCONPERSRV:-4}
APT_FAST_SPLITCON=${APT_FAST_SPLITCON:-4}
APT_FAST_MINSPLITSZ=${APT_FAST_MINSPLITSZ:-1M}

$SUDO apt-get update
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y \
  aria2 git ca-certificates

if [ -d "$APT_FAST_HOME/.git" ]; then
  echo "更新 apt-fast: $APT_FAST_HOME"
  $SUDO git -C "$APT_FAST_HOME" remote set-url origin "$APT_FAST_REPO"
  $SUDO git -C "$APT_FAST_HOME" fetch --depth 1 origin "$APT_FAST_BRANCH"
  $SUDO git -C "$APT_FAST_HOME" reset --hard "origin/$APT_FAST_BRANCH"
  $SUDO git -C "$APT_FAST_HOME" clean -fd
else
  echo "安装 apt-fast: $APT_FAST_HOME"
  $SUDO rm -rf "$APT_FAST_HOME"
  $SUDO git clone --depth 1 --branch "$APT_FAST_BRANCH" "$APT_FAST_REPO" "$APT_FAST_HOME"
fi

$SUDO install -m 0755 "$APT_FAST_HOME/apt-fast" "$APT_FAST_BIN"
# Make it available from ordinary interactive PATHs too.
$SUDO ln -sf "$APT_FAST_BIN" /usr/local/bin/apt-fast

# Keep this file deliberately small. apt-fast has sensible downloader defaults;
# only override the knobs that matter for our network and suppress its dialog.
$SUDO tee "$APT_FAST_CONF" >/dev/null <<EOF
_APTMGR=apt-get
DOWNLOADBEFORE=true
_MAXNUM=${APT_FAST_MAXNUM}
_MAXCONPERSRV=${APT_FAST_MAXCONPERSRV}
_SPLITCON=${APT_FAST_SPLITCON}
_MINSPLITSZ="${APT_FAST_MINSPLITSZ}"
_PIECEALGO="default"
EOF
$SUDO chmod 0644 "$APT_FAST_CONF"

# apt-fast does not accelerate repository metadata refresh. These settings make
# normal `apt update` fail/retry faster on unstable phone/proxy links and allow
# APT to queue different hosts independently.
$SUDO tee "$APT_NETWORK_CONF" >/dev/null <<'EOF'
Acquire::Retries "3";
Acquire::Queue-Mode "host";
Acquire::http::Timeout "15";
Acquire::https::Timeout "15";
EOF
$SUDO chmod 0644 "$APT_NETWORK_CONF"

command -v aria2c >/dev/null 2>&1 || {
  echo "错误：aria2c 未安装成功" >&2
  exit 1
}
command -v apt-fast >/dev/null 2>&1 || {
  echo "错误：apt-fast 未安装成功" >&2
  exit 1
}

echo "apt-fast 已部署"
echo "  binary: $(command -v apt-fast)"
echo "  config: $APT_FAST_CONF"
echo "  aria2 parallel jobs: $APT_FAST_MAXNUM"
echo "  per-server connections: $APT_FAST_MAXCONPERSRV"
echo "  per-file split connections: $APT_FAST_SPLITCON"
echo
echo "用法："
echo "  apt update                 # 索引刷新仍使用原生 APT"
echo "  apt-fast install <pkg>     # aria2 并行下载包"
echo "  apt-fast upgrade"
echo "  apt-fast full-upgrade"
