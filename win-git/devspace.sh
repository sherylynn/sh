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
TRAY_AUTOSTART_FILE="$AUTOSTART_DIR/devspace-tray.desktop"
TRAY_SCRIPT="$SCRIPT_DIR/devspace_tray.py"
TRAY_WATCHDOG="$SCRIPT_DIR/devspace_tray_watchdog.sh"
LAUNCH_AGENT_DIR="$RUN_HOME/Library/LaunchAgents"
LAUNCH_AGENT_FILE="$LAUNCH_AGENT_DIR/win.sherylynn.devspace.plist"

usage() {
  cat <<EOF
usage: $0 {install|deploy|enable|disable|enable-autostart|disable-autostart|autostart-status|export [archive]|import <archive>|start|stop|restart|status|token}

  install/deploy       安装并启用当前平台的自动启动入口（Linux 同时安装 XFCE DevSpace 托盘）
  enable               启用自动启动，但不强制立即启动服务（同样会补齐缺失依赖）
  disable              停止服务并关闭 DevSpace 自动启动；Linux 控制托盘仍保留自启动
  enable-autostart     只开启 DevSpace 开机自启动，不改变当前运行状态
  disable-autostart    只关闭 DevSpace 开机自启动，不改变当前运行状态
  autostart-status     输出 enabled 或 disabled
  export [archive]     导出 DevSpace + Cloudflare Tunnel 的全部持久化配置（含 OAuth 状态库）
  import <archive>     导入配置，并把源机器 HOME 路径迁移到当前 HOME
  start/stop/...       仅管理当前运行状态，不改变自动启动设置

迁移包包含 DevSpace owner token、Cloudflare tunnel credentials/cert.pem、以及 DevSpace
stateDir 里的 OAuth SQLite（已注册 client 与 access/refresh token）等敏感凭据。
请像 SSH 私钥一样保管；导出的 tar.gz 会自动设为 600 权限。

注意：不迁移 OAuth 状态库时，客户端（如 ChatGPT）缓存的 client_id/refresh_token 在目标
机器上查不到，/token 会返回 400 invalid_client —— 表现为"隧道通了但访问项目进不去"。

环境变量：CLOUDFLARED_SOURCE=brew 才会改用包管理器安装 cloudflared（默认 github）。
EOF
}

TOOLS_BIN="$RUN_HOME/tools/bin"
NODE_GLOBAL_BIN="$RUN_HOME/tools/node-global/bin"
DEVSPACE_PKG="${DEVSPACE_PKG:-@waishnav/devspace}"
CLOUDFLARED_INSTALLER="$SCRIPT_DIR/cloudflared.sh"

# --- DevSpace OAuth 状态库（关键：不在 ~/.devspace 里）---
# DevSpace 把已注册的 OAuth client 与 access/refresh token 存在 stateDir 的 SQLite 中，
# 默认 stateDir = ~/.local/share/devspace（见包内 dist/config.js 的 defaultStateDir()）。
# 只迁移 ~/.devspace 会导致客户端缓存的 client_id 在新机器上不存在，
# /token 返回 400 invalid_client，现象是「隧道通了但访问项目进不去」。
OAUTH_TABLES="oauth_clients oauth_access_tokens oauth_refresh_tokens"

resolve_state_dir() {
  local d="${DEVSPACE_STATE_DIR:-}"
  if [ -z "$d" ] && [ -f "$RUN_HOME/.devspace/config.json" ]; then
    d="$(sed -n 's/.*"stateDir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
      "$RUN_HOME/.devspace/config.json" 2>/dev/null | head -1)"
    case "$d" in
      "~"*) d="$RUN_HOME${d#\~}" ;;
    esac
  fi
  [ -n "$d" ] || d="$RUN_HOME/.local/share/devspace"
  printf '%s\n' "$d"
}

state_db_path() {
  printf '%s/devspace.sqlite\n' "$(resolve_state_dir)"
}

# 用 sqlite3 的 .backup 做一致性快照（避开 WAL 未落盘）；没有 sqlite3 时退回直接拷贝
snapshot_state_db() {
  local src="$1" dst="$2"
  [ -f "$src" ] || return 1
  mkdir -p "$(dirname "$dst")"
  if command -v sqlite3 >/dev/null 2>&1; then
    rm -f "$dst"
    if sqlite3 "$src" ".backup '$dst'" 2>/dev/null && [ -s "$dst" ]; then
      return 0
    fi
  fi
  cp -p "$src" "$dst"
}

# 定位 node 二进制目录：优先 PATH，其次 ~/tools/node/node-*/bin
find_node_dir() {
  local d
  if command -v node >/dev/null 2>&1; then
    dirname "$(command -v node)"
    return 0
  fi
  for d in "$RUN_HOME"/tools/node/node-*/bin; do
    [ -x "$d/node" ] && { printf '%s\n' "$d"; return 0; }
  done
  return 1
}

# 定位 npm：优先 PATH，其次 node 目录、~/tools/node/node-*/bin
find_npm_bin() {
  local d
  if command -v npm >/dev/null 2>&1; then
    command -v npm
    return 0
  fi
  d="$(find_node_dir 2>/dev/null || true)"
  if [ -n "$d" ] && [ -x "$d/npm" ]; then
    printf '%s\n' "$d/npm"
    return 0
  fi
  for d in "$RUN_HOME"/tools/node/node-*/bin; do
    [ -x "$d/npm" ] && { printf '%s\n' "$d/npm"; return 0; }
  done
  return 1
}

devspace_available() {
  command -v devspace >/dev/null 2>&1 || [ -x "$NODE_GLOBAL_BIN/devspace" ]
}

# macOS 上判定某个 cloudflared 是否来自 Homebrew（老系统瓶装版本过旧，不接受）
is_brew_cloudflared() {
  local path="$1" prefix
  case "$path" in
    *Cellar*|/opt/homebrew/*) return 0 ;;
  esac
  command -v brew >/dev/null 2>&1 || return 1
  prefix="$(brew --prefix 2>/dev/null || true)"
  [ -n "$prefix" ] || return 1
  case "$path" in
    "$prefix"/*) return 0 ;;
  esac
  return 1
}

# 只认官方 GitHub 独立二进制（~/tools/bin）；macOS 上 Homebrew 瓶装不算可用
cloudflared_available() {
  [ -x "$TOOLS_BIN/cloudflared" ] && return 0
  local found
  found="$(command -v cloudflared 2>/dev/null || true)"
  [ -n "$found" ] || return 1
  if [ "$OS" = "Darwin" ] && is_brew_cloudflared "$found"; then
    return 1
  fi
  return 0
}

require_runtime() {
  local missing=0
  command -v node >/dev/null 2>&1 || find_node_dir >/dev/null 2>&1 \
    || { echo "错误：未找到 node" >&2; missing=1; }
  devspace_available \
    || { echo "错误：未找到 devspace CLI（可执行 $0 install 自动安装）" >&2; missing=1; }
  cloudflared_available \
    || { echo "错误：未找到 cloudflared（可执行 $0 install 自动安装）" >&2; missing=1; }
  [ "$missing" -eq 0 ]
}

ensure_node() {
  if command -v node >/dev/null 2>&1 || find_node_dir >/dev/null 2>&1; then
    return 0
  fi
  echo "→ 未找到 node，开始安装..."
  if [ "$OS" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    brew install node
  elif [ "$OS" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y nodejs npm
  else
    echo "错误：未找到 node，且无可用包管理器；请手动安装 Node >=22.19 <27" >&2
    return 1
  fi
}

ensure_devspace_cli() {
  devspace_available && return 0
  local npm_bin
  npm_bin="$(find_npm_bin || true)"
  if [ -z "$npm_bin" ]; then
    echo "错误：未找到 npm，无法安装 devspace CLI" >&2
    return 1
  fi
  echo "→ 未找到 devspace CLI，使用 npm 安装 $DEVSPACE_PKG ..."
  "$npm_bin" install -g "$DEVSPACE_PKG" \
    || { echo "错误：$DEVSPACE_PKG 安装失败" >&2; return 1; }
  if ! devspace_available; then
    echo "错误：devspace CLI 安装后仍不可用（预期路径：$NODE_GLOBAL_BIN/devspace）" >&2
    return 1
  fi
  echo "devspace CLI 已安装：$(command -v devspace 2>/dev/null || echo "$NODE_GLOBAL_BIN/devspace")"
}

# 安装/更新 cloudflared：统一委托给 win-git/cloudflared.sh
# （只从 GitHub 官方 release 取独立二进制到 ~/tools/bin，macLinux 都不碰 brew/apt）
install_cloudflared_binary() {
  [ -f "$CLOUDFLARED_INSTALLER" ] \
    || { echo "错误：找不到 cloudflared 安装脚本：$CLOUDFLARED_INSTALLER" >&2; return 1; }
  if command -v zsh >/dev/null 2>&1; then
    zsh "$CLOUDFLARED_INSTALLER"
  else
    bash "$CLOUDFLARED_INSTALLER"
  fi
}

ensure_cloudflared() {
  # 默认始终使用 GitHub 官方独立二进制；CLOUDFLARED_SOURCE=brew 才走包管理器
  local src="${CLOUDFLARED_SOURCE:-github}"
  if [ "$src" != "brew" ] && cloudflared_available; then
    return 0
  fi
  echo "→ 安装 cloudflared（source=${src}）..."
  if [ "$src" = "brew" ]; then
    if [ "$OS" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
      brew install cloudflared
    else
      install_cloudflared_binary || return 1
    fi
  else
    install_cloudflared_binary || return 1
  fi
  if ! cloudflared_available; then
    echo "错误：cloudflared 安装后仍不可用（预期：$TOOLS_BIN/cloudflared）" >&2
    return 1
  fi
  echo "cloudflared 已就绪：$(command -v cloudflared 2>/dev/null || echo "$TOOLS_BIN/cloudflared")"
}

# install/enable 前先补齐依赖，再做最终校验
ensure_runtime() {
  ensure_node
  ensure_devspace_cli
  ensure_cloudflared
  require_runtime
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

  # XFCE 托盘只负责交互控制；真正的服务生命周期仍统一走本脚本/server_devspace.sh。
  # Gtk.StatusIcon 与显示设置托盘保持一致，避免依赖 Ayatana indicator service。
  if [ -f "$TRAY_SCRIPT" ] && [ -f "$TRAY_WATCHDOG" ]; then
    chmod 755 "$TRAY_SCRIPT" "$TRAY_WATCHDOG"
    cat >"$TRAY_AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=DevSpace MCP Tray
Comment=Start, stop, import and export DevSpace MCP configuration
Exec=$TRAY_WATCHDOG
Icon=network-server
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
OnlyShowIn=XFCE;
EOF
    chmod 644 "$TRAY_AUTOSTART_FILE"
  fi
  echo "desktop autostart: $AUTOSTART_FILE"
  echo "DevSpace tray autostart: $TRAY_AUTOSTART_FILE"
}

disable_linux_autostart() {
  # 这里只关闭 DevSpace 服务的开机启动。控制托盘本身继续自启动，
  # 这样用户即使关闭了服务自启动，下次登录仍可从托盘重新开启。
  rm -f "$AUTOSTART_FILE"

  if [ -e /etc/rc3.d/S01devspace ] || [ -L /etc/rc3.d/S01devspace ]; then
    if [ "$(id -u)" -eq 0 ]; then
      rm -f /etc/rc3.d/S01devspace
    else
      sudo rm -f /etc/rc3.d/S01devspace
    fi
  fi

  if [ -e /etc/init.d/devspace ]; then
    if [ "$(id -u)" -eq 0 ]; then
      rm -f /etc/init.d/devspace
    else
      sudo rm -f /etc/init.d/devspace
    fi
  fi

  echo "Linux 自动启动已关闭"
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
  <key>AbandonProcessGroup</key><true/>
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

disable_macos_autostart() {
  launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_FILE" >/dev/null 2>&1 || true
  rm -f "$LAUNCH_AGENT_FILE"
  echo "macOS 自动启动已关闭"
}

enable_autostart() {
  ensure_runtime
  case "$OS" in
    Linux) install_linux_autostart ;;
    Darwin) install_macos_autostart ;;
    *) echo "错误：暂不支持平台：$OS" >&2; return 1 ;;
  esac
}

disable_autostart_only() {
  case "$OS" in
    Linux) disable_linux_autostart ;;
    Darwin) disable_macos_autostart ;;
    *) echo "错误：暂不支持平台：$OS" >&2; return 1 ;;
  esac
}

autostart_enabled() {
  case "$OS" in
    Linux)
      [ -e /etc/rc3.d/S01devspace ] || [ -L /etc/rc3.d/S01devspace ] || [ -f "$AUTOSTART_FILE" ]
      ;;
    Darwin)
      [ -f "$LAUNCH_AGENT_FILE" ]
      ;;
    *) return 1 ;;
  esac
}

disable_autostart() {
  /bin/bash "$SERVER_SCRIPT" stop || true
  disable_autostart_only
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

  # OAuth 状态库：客户端缓存的 client_id/refresh_token 全靠它，漏了会导致 /token 400
  local state_db
  state_db="$(state_db_path)"
  if snapshot_state_db "$state_db" "$tmp/payload/state/devspace.sqlite"; then
    echo "已包含 OAuth 状态库：$state_db"
  else
    echo "提示：未找到 OAuth 状态库（${state_db}），跳过"
  fi

  # server_devspace.sh 支持该持久化参数文件；旧安装没有时在首次导出时补齐。
  mkdir -p "$tmp/payload/devspace"
  if [ ! -f "$tmp/payload/devspace/service.env" ]; then
    cat >"$tmp/payload/devspace/service.env" <<EOF
DEVSPACE_TUNNEL_NAME=${DEVSPACE_TUNNEL_NAME:-devspace}
PUBLIC_HOST=${PUBLIC_HOST:-devspace.sherylynn.win}
DEVSPACE_ALLOWED_ROOTS=${DEVSPACE_ALLOWED_ROOTS:-$RUN_HOME/sh,$RUN_HOME/newhome,$RUN_HOME/plan,$RUN_HOME/ghostlock-app,$RUN_HOME/note_agent}
EOF
  elif ! grep -q '^DEVSPACE_ALLOWED_ROOTS=' "$tmp/payload/devspace/service.env"; then
    printf '%s\n' "DEVSPACE_ALLOWED_ROOTS=${DEVSPACE_ALLOWED_ROOTS:-$RUN_HOME/sh,$RUN_HOME/newhome,$RUN_HOME/plan,$RUN_HOME/ghostlock-app,$RUN_HOME/note_agent}" >>"$tmp/payload/devspace/service.env"
  fi
  chmod 600 "$tmp/payload/devspace/service.env"

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
  echo "包含：~/.devspace 持久化设置 + ~/.cloudflared 全部设置/凭据 + OAuth 状态库"
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
  local backup_dir="$RUN_HOME/.devspace-migration-backup-$(date '+%Y%m%d-%H%M%S')" state_db
  if [ -d "$RUN_HOME/.devspace" ] || [ -d "$RUN_HOME/.cloudflared" ]; then
    mkdir -p "$backup_dir"
    [ ! -d "$RUN_HOME/.devspace" ] || cp -Rp "$RUN_HOME/.devspace" "$backup_dir/devspace"
    [ ! -d "$RUN_HOME/.cloudflared" ] || cp -Rp "$RUN_HOME/.cloudflared" "$backup_dir/cloudflared"
    state_db="$(state_db_path)"
    snapshot_state_db "$state_db" "$backup_dir/devspace.sqlite" 2>/dev/null || true
    chmod 700 "$backup_dir"
    echo "现有配置已备份：$backup_dir"
  fi
}

# 把迁移包里的 OAuth 状态合并进本机 stateDir：
# 只搬运 oauth_* 三张表（client 与 token），不搬 workspace/session 表，
# 避免把源机器的绝对路径带进来。
import_oauth_state() {
  local src_db="$1" dst_db table
  [ -f "$src_db" ] || return 0
  dst_db="$(state_db_path)"

  if [ ! -f "$dst_db" ]; then
    mkdir -p "$(dirname "$dst_db")"
    cp -p "$src_db" "$dst_db"
    chmod 600 "$dst_db"
    echo "已导入 OAuth 状态库（本机原本没有）：$dst_db"
    return 0
  fi

  if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "警告：未找到 sqlite3，无法合并已有 OAuth 状态库；ChatGPT 端需重新授权。" >&2
    return 0
  fi

  for table in $OAUTH_TABLES; do
    # 两个坑：① .bail on 必须作为独立参数传入（与 SQL 拼成多行时 sqlite3 报 Usage: .bail on|off），
    #         sqlite3 CLI 默认遇错仍返回 0，不加它则失败会被误判成成功；
    #         ② 目标表必须写成 main.<table> —— ATTACH 之后未限定的表名在 main 里不存在时会
    #         解析到 attached 库，变成「往源库自己插自己」并照样返回 0。
    if sqlite3 "$dst_db" ".bail on" \
      "ATTACH '$src_db' AS src; INSERT OR REPLACE INTO main.$table SELECT * FROM src.$table; DETACH src;" \
      >/dev/null 2>&1; then
      echo "已合并 OAuth 表：${table}"
    else
      echo "提示：跳过 OAuth 表 ${table}（结构不匹配或不存在）"
    fi
  done
  chmod 600 "$dst_db"
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
  rewrite_home_paths "$source_home" "$RUN_HOME/.devspace/service.env"

  # OAuth 状态：必须在 DevSpace 停止状态下合并（上面已经 stop 过）
  import_oauth_state "$tmp/payload/state/devspace.sqlite"

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
    enable_autostart
    echo
    echo "DevSpace MCP 已部署并启用自动启动。"
    echo "服务管理：$SERVER_SCRIPT {start|stop|restart|status|token}"
    ;;
  enable)
    enable_autostart
    echo "DevSpace MCP 自动启动已启用。"
    ;;
  disable)
    disable_autostart
    echo "DevSpace MCP 已停止，自动启动已禁用。"
    ;;
  enable-autostart)
    enable_autostart
    echo "DevSpace MCP 自动启动已启用；当前运行状态未改变。"
    ;;
  disable-autostart)
    disable_autostart_only
    echo "DevSpace MCP 自动启动已禁用；当前运行状态未改变。"
    ;;
  autostart-status)
    if autostart_enabled; then
      echo enabled
    else
      echo disabled
    fi
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
