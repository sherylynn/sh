#!/usr/bin/env bash
# devspace.sh —— DevSpace MCP 安装/部署入口。
#
# 本仓库命名约定：
#   devspace.sh          安装/部署
#   server_devspace.sh   服务启停
#   init_d_devspace.sh   注册 SysV/rc3 自启动
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd)"
SERVER_SCRIPT="$SCRIPT_DIR/server_devspace.sh"
INIT_SCRIPT="$SCRIPT_DIR/init_d_devspace.sh"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/devspace.desktop"

if ! command -v node >/dev/null 2>&1; then
  echo "错误：未找到 node，请先使用本仓库 nodejs.sh 安装 Node.js" >&2
  exit 1
fi

if ! command -v devspace >/dev/null 2>&1 && [ ! -x "$HOME/tools/node-global/bin/devspace" ]; then
  echo "错误：未找到 devspace，请先安装 DevSpace MCP CLI" >&2
  exit 1
fi

case "${1:-install}" in
  install|deploy)
    /bin/bash "$INIT_SCRIPT"

    # Desktop session is the second startup path. It intentionally calls the
    # same service manager as rc3; server_devspace.sh makes start idempotent.
    mkdir -p "$AUTOSTART_DIR"
    cat >"$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=DevSpace MCP + Cloudflare Tunnel
Comment=Start DevSpace MCP service manager
Exec=/bin/bash -lc '$SERVER_SCRIPT start'
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=XFCE;
EOF
    chmod 644 "$AUTOSTART_FILE"

    echo
    echo "DevSpace MCP 已部署。"
    echo "desktop autostart: $AUTOSTART_FILE"
    echo "服务管理：$SERVER_SCRIPT {start|stop|restart|status|token}"
    echo "rc3 与 desktop/autostart 可同时保留；server_devspace.sh 会防止重复启动。"
    ;;
  start|stop|restart|status|token)
    exec /bin/bash "$SERVER_SCRIPT" "$@"
    ;;
  *)
    echo "usage: $0 {install|deploy|start|stop|restart|status|token}" >&2
    exit 1
    ;;
esac
