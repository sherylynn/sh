#!/bin/bash
set -euo pipefail

# Xpra deployment script.
# Mirrors win-git/noVNC.sh: this file only installs/configures Xpra.

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

if [ ! -r /etc/os-release ]; then
  echo "错误：无法识别 Linux 发行版（缺少 /etc/os-release）" >&2
  exit 1
fi

. /etc/os-release
CODENAME=${VERSION_CODENAME:-}
if [ -z "$CODENAME" ]; then
  echo "错误：无法识别发行版 codename" >&2
  exit 1
fi

echo "Xpra target: ${PRETTY_NAME:-unknown} (${CODENAME}) / $(dpkg --print-architecture 2>/dev/null || uname -m)"

$SUDO apt-get update
$SUDO apt-get install -y ca-certificates wget openssl dbus-x11 xauth

# Prefer Xpra's official stable repository. Debian's own Bookworm package is
# much older; the official repository provides the current v6 server and HTML5
# client packages for supported Debian/Ubuntu releases.
XPRA_KEY=/usr/share/keyrings/xpra.asc
XPRA_SOURCE=/etc/apt/sources.list.d/xpra.sources
XPRA_SOURCE_URL="https://raw.githubusercontent.com/Xpra-org/xpra/master/packaging/repos/${CODENAME}/xpra.sources"

repo_ok=0
if $SUDO wget -qO "$XPRA_KEY" https://xpra.org/xpra.asc; then
  if $SUDO wget -qO "$XPRA_SOURCE" "$XPRA_SOURCE_URL"; then
    repo_ok=1
    echo "已启用 Xpra stable repository: $CODENAME"
  else
    echo "警告：Xpra stable repository 不支持 ${CODENAME}，回退到系统仓库" >&2
    $SUDO rm -f "$XPRA_SOURCE"
  fi
else
  echo "警告：无法下载 Xpra repository key，回退到系统仓库" >&2
  $SUDO rm -f "$XPRA_KEY" "$XPRA_SOURCE"
fi

$SUDO apt-get update
if apt-cache show xpra-html5 >/dev/null 2>&1; then
  $SUDO apt-get install -y xpra xpra-html5
else
  $SUDO apt-get install -y xpra
fi

command -v xpra >/dev/null 2>&1 || {
  echo "错误：Xpra 安装后仍找不到 xpra 命令" >&2
  exit 1
}

XPRA_DIR=/root/.xpra
XPRA_PASSWORD_FILE=${XPRA_PASSWORD_FILE:-$XPRA_DIR/newhome-password.txt}
$SUDO install -d -m 700 "$XPRA_DIR"

if ! $SUDO test -s "$XPRA_PASSWORD_FILE"; then
  password=""
  if $SUDO test -r /root/.vnc/wayvnc.credentials; then
    password=$($SUDO sed -n 's/^password=//p' /root/.vnc/wayvnc.credentials | head -1)
  fi
  if [ -z "$password" ]; then
    password=$(openssl rand -base64 24 | tr -d '\n')
  fi
  printf '%s\n' "$password" | $SUDO tee "$XPRA_PASSWORD_FILE" >/dev/null
  $SUDO chmod 600 "$XPRA_PASSWORD_FILE"
  echo "已创建 Xpra 登录密码文件：$XPRA_PASSWORD_FILE"
else
  echo "保留现有 Xpra 登录密码文件：$XPRA_PASSWORD_FILE"
fi

# Install the rc3 wrapper separately from the runtime script, matching the
# existing noVNC.sh / server_noVNC.sh / init_d_noVNC.sh split.
INIT_SCRIPT="$(cd "$(dirname "$0")" && pwd)/init_d_xpra.sh"
if [ -f "$INIT_SCRIPT" ]; then
  /bin/bash "$INIT_SCRIPT"
else
  echo "警告：未找到 $INIT_SCRIPT；Xpra 已安装，但尚未注册 rc3 自启动" >&2
fi

echo "Xpra version: $(xpra --version 2>/dev/null | head -1)"
if [ "$repo_ok" -eq 1 ]; then
  echo "安装来源：Xpra official stable repository"
else
  echo "安装来源：distribution repository"
fi
echo "运行入口：/root/sh/win-git/server_xpra.sh"
echo "服务入口：/etc/init.d/xpra start|stop|status"
echo "HTML5 默认端口：10087（默认仅监听 127.0.0.1，适合 adb forward）"
echo "密码文件：$XPRA_PASSWORD_FILE"
echo "若已有 noVNC/wayvnc 凭据，首次安装会复用其中的 password；否则可用 sudo cat $XPRA_PASSWORD_FILE 查看自动生成的密码。"
