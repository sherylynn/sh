#!/usr/bin/env bash
# devspace.sh —— DevSpace MCP 安装、部署与跨机器迁移入口。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd)"
SERVER_SCRIPT="$SCRIPT_DIR/server_devspace.sh"
INIT_SCRIPT="$SCRIPT_DIR/init_d_devspace.sh"
OS="$(uname -s)"
RUN_HOME="${DEVSPACE_HOME:-$HOME}"
MIGRATION_VERSION=1

AUTOSTART_DIR="${XDG_CONFIG_HOME:-$RUN_HOME/.config}/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/devspace.desktop"
LAUNCH_AGENT_DIR="$RUN_HOME/Library/LaunchAgents"
LAUNCH_AGENT_FILE="$LAUNCH_AGENT_DIR/win.sherylynn.devspace.plist"

usage() {
  cat <<EOF
usage: $0 {install|deploy|export [archive]|import <archive>|start|stop|restart|status|token}

  install/deploy       安装当前平台的自动启动入口
  export [archive]     导出 DevSpace + Cloudflare Tunnel 的全部持久化配置
  import <archive>     导入配置，并把源机器 HOME 路径迁移到当前 HOME
  start/stop/...       交给 server_devspace.sh 管理服务

迁移包包含 DevSpace owner token、Cloudflare tunnel credentials/cert.pem 等敏感凭据。
请像 SSH 私钥一样保管；导出的 tar.gz 会自动设为 600 权限。
EOF
}

require_runtime() {
  local missing=0
  command -v node >/dev/null 2>&1 || { echo "错误：未找到 node" >&2; missing=1; }
  if ! command -v devspace >/dev/null 2>&1 && [ ! -x "$RUN_HOME/tools/node-global/bin/devspace" ]; then
    echo "错误：未找到 devspace CLI" >&2
    missing=1
  fi
  command -v cloudflared >/dev/null 2>&1 || { echo "错误：未找到 cloudflared" >&2; missing=1; }
  [ "$missing" -eq 0 ]
}

install_linux_autostart() {
  /bin/bash "$INIT_SCRIPT"
  mkdir -p "$AUTOSTART_DIR"
  cat >"$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=DevSpace MCP + Cloudflare Tunnel
Comment=Start DevSpace MCP service manager
Exec=/bin/bash $SERVER_SCRIPT start
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=XFCE;
EOF
  chmod 644 "$AUTOSTART_FILE"
  echo "desktop autostart: $AUTOSTART_FILE"
}

install_macos_autostart() {
  mkdir -p "$LAUNCH_AGENT_DIR" "$RUN_HOME/.devspace"
  cat >"$LAUNCH_AGENT_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>win.sherylynn.devspace</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SERVER_SCRIPT</string>
    <string>start</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$RUN_HOME/.devspace/launchagent.log</string>
  <key>StandardErrorPath</key><string>$RUN_HOME/.devspace/launchagent.log</string>
</dict>
</plist>
EOF
  chmod 644 "$LAUNCH_AGENT_FILE"
  launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_FILE" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_FILE"
  echo "macOS LaunchAgent: $LAUNCH_AGENT_FILE"
}

export_config() {
  local archive="${1:-}" tmp
  if [ -z "$archive" ]; then
    archive="$PWD/devspace-mcp-$(hostname 2>/dev/null || echo host)-$(date '+%Y%m%d-%H%M%S').tar.gz"
  elif [[ "$archive" != /* ]]; then
    archive="$PWD/$archive"
  fi

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/devspace-export.XXXXXX")"
  trap 'rm -rf "$tmp"' RETURN
  mkdir -p "$tmp/payload"

  if [ -d "$RUN_HOME/.devspace" ]; then
    cp -Rp "$RUN_HOME/.devspace" "$tmp/payload/devspace"
    rm -rf "$tmp/payload/devspace/run"
    rm -f "$tmp/payload/devspace/initd.log" \
      "$tmp/payload/devspace/launchagent.log" \
      "$tmp/payload/devspace/devspace-serve.log" \
      "$tmp/payload/devspace/cloudflared.log"
  fi

  if [ -d "$RUN_HOME/.cloudflared" ]; then
    cp -Rp "$RUN_HOME/.cloudflared" "$tmp/payload/cloudflared"
  fi

  # server_devspace.sh 支持该持久化参数文件；旧安装没有时在首次导出时补齐。
  mkdir -p "$tmp/payload/devspace"
  if [ ! -f "$tmp/payload/devspace/service.env" ]; then
    cat >"$tmp/payload/devspace/service.env" <<EOF
DEVSPACE_TUNNEL_NAME=${DEVSPACE_TUNNEL_NAME:-devspace}
PUBLIC_HOST=${PUBLIC_HOST:-devspace.sherylynn.win}
EOF
    chmod 600 "$tmp/payload/devspace/service.env"
  fi

  cat >"$tmp/manifest" <<EOF
format=devspace-mcp-migration
version=$MIGRATION_VERSION
source_home=$RUN_HOME
source_os=$OS
source_host=$(hostname 2>/dev/null || echo unknown)
created_at=$(date '+%Y-%m-%dT%H:%M:%S%z')
EOF

  mkdir -p "$(dirname "$archive")"
  tar -C "$tmp" -czf "$archive" manifest payload
  chmod 600 "$archive"

  echo "已导出：$archive"
  echo "包含：~/.devspace 持久化设置 + ~/.cloudflared 全部设置/凭据"
  echo "注意：该文件包含可用于接管 MCP 与 Cloudflare Tunnel 的敏感凭据。"
}

rewrite_home_paths() {
  local old_home="$1" file="$2" tmp
  [ -f "$file" ] || return 0
  [ -n "$old_home" ] || return 0
  [ "$old_home" = "$RUN_HOME" ] && return 0

  tmp="${file}.tmp.$$"
  OLD_HOME="$old_home" NEW_HOME="$RUN_HOME" perl -pe 's/\Q$ENV{OLD_HOME}\E/$ENV{NEW_HOME}/g' "$file" >"$tmp"
  mv "$tmp" "$file"
}

validate_archive() {
  local archive="$1" entry
  while IFS= read -r entry; do
    case "$entry" in
      /*|../*|*/../*|*/..)
        echo "错误：迁移包包含不安全路径：$entry" >&2
        return 1
        ;;
    esac
  done < <(tar -tzf "$archive")
}

backup_existing_config() {
  local backup_dir="$RUN_HOME/.devspace-migration-backup-$(date '+%Y%m%d-%H%M%S')"
  if [ -d "$RUN_HOME/.devspace" ] || [ -d "$RUN_HOME/.cloudflared" ]; then
    mkdir -p "$backup_dir"
    [ ! -d "$RUN_HOME/.devspace" ] || cp -Rp "$RUN_HOME/.devspace" "$backup_dir/devspace"
    [ ! -d "$RUN_HOME/.cloudflared" ] || cp -Rp "$RUN_HOME/.cloudflared" "$backup_dir/cloudflared"
    chmod 700 "$backup_dir"
    echo "现有配置已备份：$backup_dir"
  fi
}

import_config() {
  local archive="${1:-}" tmp manifest format version source_home
  [ -n "$archive" ] || { echo "错误：import 需要迁移包路径" >&2; return 2; }
  [ -f "$archive" ] || { echo "错误：文件不存在：$archive" >&2; return 2; }

  validate_archive "$archive"

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/devspace-import.XXXXXX")"
  trap 'rm -rf "$tmp"' RETURN
  tar -C "$tmp" -xzf "$archive"

  manifest="$tmp/manifest"
  [ -f "$manifest" ] || { echo "错误：不是有效的 DevSpace MCP 迁移包" >&2; return 2; }

  format="$(grep '^format=' "$manifest" | head -1 | cut -d= -f2-)"
  version="$(grep '^version=' "$manifest" | head -1 | cut -d= -f2-)"
  source_home="$(grep '^source_home=' "$manifest" | head -1 | cut -d= -f2-)"

  [ "$format" = "devspace-mcp-migration" ] || { echo "错误：未知迁移包格式：$format" >&2; return 2; }
  [ "$version" = "$MIGRATION_VERSION" ] || { echo "错误：不支持的迁移包版本：$version" >&2; return 2; }
  [ -n "$source_home" ] || { echo "错误：迁移包缺少 source_home" >&2; return 2; }

  /bin/bash "$SERVER_SCRIPT" stop >/dev/null 2>&1 || true
  backup_existing_config

  # 迁移的目标是完整复现源机器的持久化设置，而不是与目标旧设置混合。
  rm -rf "$RUN_HOME/.devspace" "$RUN_HOME/.cloudflared"

  if [ -d "$tmp/payload/devspace" ]; then
    mkdir -p "$RUN_HOME/.devspace"
    cp -Rp "$tmp/payload/devspace/." "$RUN_HOME/.devspace/"
  fi

  if [ -d "$tmp/payload/cloudflared" ]; then
    mkdir -p "$RUN_HOME/.cloudflared"
    cp -Rp "$tmp/payload/cloudflared/." "$RUN_HOME/.cloudflared/"
  fi

  rewrite_home_paths "$source_home" "$RUN_HOME/.cloudflared/config.yml"
  rewrite_home_paths "$source_home" "$RUN_HOME/.devspace/config.json"
  rewrite_home_paths "$source_home" "$RUN_HOME/.devspace/config.jsonc"

  rm -rf "$RUN_HOME/.devspace/run"
  rm -f "$RUN_HOME/.devspace/initd.log" \
    "$RUN_HOME/.devspace/launchagent.log" \
    "$RUN_HOME/.devspace/devspace-serve.log" \
    "$RUN_HOME/.devspace/cloudflared.log"

  chmod 700 "$RUN_HOME/.devspace" "$RUN_HOME/.cloudflared" 2>/dev/null || true
  chmod 600 "$RUN_HOME/.devspace/owner-token" "$RUN_HOME/.devspace/auth.json" 2>/dev/null || true
  chmod 600 "$RUN_HOME/.cloudflared/"*.json "$RUN_HOME/.cloudflared/cert.pem" 2>/dev/null || true

  echo "已导入：$source_home -> $RUN_HOME"
  echo "Cloudflare named tunnel 与 DevSpace 身份/配置已迁移。"
  echo "接下来执行：$0 install"
  echo "然后执行：$SERVER_SCRIPT start"
}

case "${1:-install}" in
  install|deploy)
    require_runtime
    case "$OS" in
      Linux) install_linux_autostart ;;
      Darwin) install_macos_autostart ;;
      *) echo "错误：暂不支持平台：$OS" >&2; exit 1 ;;
    esac
    echo
    echo "DevSpace MCP 已部署。"
    echo "服务管理：$SERVER_SCRIPT {start|stop|restart|status|token}"
    ;;
  export)
    shift
    export_config "${1:-}"
    ;;
  import)
    shift
    import_config "${1:-}"
    ;;
  start|stop|restart|status|token)
    require_runtime
    exec /bin/bash "$SERVER_SCRIPT" "$@"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
