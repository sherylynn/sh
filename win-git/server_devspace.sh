#!/usr/bin/env bash
# server_devspace.sh —— DevSpace MCP server + Cloudflare named tunnel service manager.
# Linux chroot / macOS 共用；start 幂等，所有自启动入口都可以安全调用。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OS="$(uname -s)"

if [ "$(id -u)" -eq 0 ]; then
  export HOME="${DEVSPACE_HOME:-/root}"
fi

RUN_HOME="${DEVSPACE_HOME:-${HOME:-/root}}"
CONFIG_DIR="${DEVSPACE_CONFIG_DIR:-$RUN_HOME/.devspace}"
TOKEN_FILE="$CONFIG_DIR/owner-token"
SERVICE_ENV="$CONFIG_DIR/service.env"
RUN_DIR="${DEVSPACE_RUN_DIR:-$CONFIG_DIR/run}"
SERVE_PID_FILE="$RUN_DIR/devspace.pid"
TUNNEL_PID_FILE="$RUN_DIR/cloudflared.pid"

SERVE_LOG="${DEVSPACE_SERVE_LOG:-$CONFIG_DIR/devspace-serve.log}"
TUNNEL_LOG="${DEVSPACE_TUNNEL_LOG:-$CONFIG_DIR/cloudflared.log}"

read_service_setting() {
  local key="$1"
  [ -f "$SERVICE_ENV" ] || return 0
  grep -E "^${key}=" "$SERVICE_ENV" 2>/dev/null | tail -1 | cut -d= -f2-
}

PERSISTED_TUNNEL_NAME="$(read_service_setting DEVSPACE_TUNNEL_NAME)"
PERSISTED_PUBLIC_HOST="$(read_service_setting PUBLIC_HOST)"
PERSISTED_ALLOWED_ROOTS="$(read_service_setting DEVSPACE_ALLOWED_ROOTS)"
PERSISTED_WIDGETS="$(read_service_setting DEVSPACE_WIDGETS)"
PERSISTED_DEVSPACE_AUTOSTART="$(read_service_setting DEVSPACE_AUTOSTART)"
PERSISTED_CLOUDFLARED_AUTOSTART="$(read_service_setting CLOUDFLARED_AUTOSTART)"

DEVSPACE_AUTOSTART="${DEVSPACE_AUTOSTART:-${PERSISTED_DEVSPACE_AUTOSTART:-1}}"
CLOUDFLARED_AUTOSTART="${CLOUDFLARED_AUTOSTART:-${PERSISTED_CLOUDFLARED_AUTOSTART:-1}}"
TUNNEL_NAME="${DEVSPACE_TUNNEL_NAME:-${PERSISTED_TUNNEL_NAME:-devspace}}"
DEVSPACE_ALLOWED_ROOTS="${DEVSPACE_ALLOWED_ROOTS:-${PERSISTED_ALLOWED_ROOTS:-$RUN_HOME/sh,$RUN_HOME/newhome,$RUN_HOME/plan,$RUN_HOME/ghostlock-app,$RUN_HOME/note_agent}}"
export DEVSPACE_ALLOWED_ROOTS
# DevSpace 1.0.x 使用 DEVSPACE_WIDGETS 控制 ChatGPT Apps/UI metadata。
# off 只关闭网页里的工具 UI，不关闭 MCP 工具本身；默认 off，service.env 可覆盖。
DEVSPACE_WIDGETS="${DEVSPACE_WIDGETS:-${PERSISTED_WIDGETS:-off}}"
export DEVSPACE_WIDGETS
CLOUDFLARED_CONFIG="${CLOUDFLARED_CONFIG:-$RUN_HOME/.cloudflared/config.yml}"
# 隧道传输协议：空/auto 交回 cloudflared 自决（默认 quic）。
# 本机有 fake-IP/TUN 代理时 QUIC(UDP 7844) 会被吞，必须 http2(TCP 443)。
# 用启动 flag 而不是写进 config.yml —— config.yml 会被 devspace.sh import 整体
# 替换（导入包来自没有该问题的机器），写成 flag 才能跨迁移保持。
CLOUDFLARED_PROTOCOL="${CLOUDFLARED_PROTOCOL:-http2}"
WORKDIR="${DEVSPACE_WORKDIR:-$REPO_ROOT}"
PUBLIC_HOST="${PUBLIC_HOST:-${PERSISTED_PUBLIC_HOST:-devspace.sherylynn.win}}"

export PATH="$RUN_HOME/tools/bin:$RUN_HOME/tools/node-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}"

if ! command -v node >/dev/null 2>&1; then
  for _d in "$RUN_HOME"/tools/node/node-*/bin; do
    [ -x "$_d/node" ] && export PATH="$_d:$PATH" && break
  done
fi

DEVSPACE_BIN="${DEVSPACE_BIN:-$(command -v devspace 2>/dev/null || echo "$RUN_HOME/tools/node-global/bin/devspace")}"
CLOUDFLARED_BIN="${CLOUDFLARED_BIN:-$(command -v cloudflared 2>/dev/null || echo cloudflared)}"

LOCK_FILE="${DEVSPACE_LOCK_FILE:-${TMPDIR:-/tmp}/.devspace-service-$(id -u).lock}"
LOCK_DIR="${DEVSPACE_LOCK_DIR:-${LOCK_FILE}.d}"

SERVE_PAT="(^|/)([^ ]*/)?node [^ ]*devspace(\.js)? serve( |$)"
# 启动命令形如：cloudflared tunnel --config CFG run [--protocol http2] devspace
# 隧道名前面可能还有 --protocol 等 flag，故 run 与隧道名之间允许跨 token。
TUNNEL_PAT="(^|/)cloudflared( |$).*tunnel( |$).*run( |$).*${TUNNEL_NAME}( |$)"

ensure_dirs() {
  mkdir -p "$CONFIG_DIR" "$RUN_DIR"
  chmod 700 "$CONFIG_DIR" "$RUN_DIR" 2>/dev/null || true
}

ensure_token() {
  ensure_dirs
  [ -s "$TOKEN_FILE" ] || openssl rand -base64 32 >"$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  if [ ! -s "$CONFIG_DIR/auth.json" ]; then
    printf '{\n  "ownerToken": "%s"\n}\n' "$(cat "$TOKEN_FILE")" >"$CONFIG_DIR/auth.json"
    chmod 600 "$CONFIG_DIR/auth.json"
  fi
}

pid_alive() {
  local file="$1" pid
  [ -s "$file" ] || return 1
  pid="$(cat "$file" 2>/dev/null || true)"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

pid_matches() {
  local file="$1" pat="$2" pid command_line
  pid_alive "$file" || return 1
  pid="$(cat "$file")"
  command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  [ -n "$command_line" ] && printf '%s\n' "$command_line" | grep -Eq "$pat"
}

find_matching_pid() {
  pgrep -f "$1" 2>/dev/null | head -1
}

remember_existing_pid() {
  local pat="$1" file="$2" pid
  pid_matches "$file" "$pat" && return 0
  rm -f "$file"
  pid="$(find_matching_pid "$pat")"
  if [ -n "$pid" ]; then
    printf '%s\n' "$pid" >"$file"
    return 0
  fi
  rm -f "$file"
  return 1
}

start_background() {
  local pid_file="$1" log_file="$2"
  shift 2
  nohup "$@" </dev/null >>"$log_file" 2>&1 &
  printf '%s\n' "$!" >"$pid_file"
}

start_devspace_unlocked() {
  ensure_token
  export DEVSPACE_OAUTH_OWNER_TOKEN="$(cat "$TOKEN_FILE")"
  [ -x "$DEVSPACE_BIN" ] || { echo "错误：找不到 devspace 可执行文件（${DEVSPACE_BIN}）" >&2; return 1; }
  [ -d "$WORKDIR" ] || { echo "错误：DevSpace 工作目录不存在：$WORKDIR" >&2; return 1; }
  if remember_existing_pid "$SERVE_PAT" "$SERVE_PID_FILE"; then
    echo "devspace serve 已在运行（PID $(cat "$SERVE_PID_FILE")），本次不重复启动"
  else
    (
      cd "$WORKDIR" || exit 1
      start_background "$SERVE_PID_FILE" "$SERVE_LOG" "$DEVSPACE_BIN" serve
    )
    echo "devspace serve 已启动（PID $(cat "$SERVE_PID_FILE")）-> $SERVE_LOG"
  fi
}

start_cloudflared_unlocked() {
  if ! command -v "$CLOUDFLARED_BIN" >/dev/null 2>&1 && [ ! -x "$CLOUDFLARED_BIN" ]; then
    echo "错误：找不到 cloudflared（${CLOUDFLARED_BIN}）" >&2
    return 1
  fi
  [ -f "$CLOUDFLARED_CONFIG" ] || { echo "错误：找不到 Cloudflare 配置：$CLOUDFLARED_CONFIG" >&2; return 1; }
  if remember_existing_pid "$TUNNEL_PAT" "$TUNNEL_PID_FILE"; then
    echo "cloudflared 隧道已在运行（PID $(cat "$TUNNEL_PID_FILE")），本次不重复启动"
  else
    local args
    args=(tunnel --config "$CLOUDFLARED_CONFIG" run)
    case "$CLOUDFLARED_PROTOCOL" in
      ""|auto) ;;
      *) args+=(--protocol "$CLOUDFLARED_PROTOCOL") ;;
    esac
    args+=("$TUNNEL_NAME")
    start_background "$TUNNEL_PID_FILE" "$TUNNEL_LOG" "$CLOUDFLARED_BIN" "${args[@]}"
    echo "cloudflared 隧道已启动（PID $(cat "$TUNNEL_PID_FILE")${CLOUDFLARED_PROTOCOL:+, protocol=${CLOUDFLARED_PROTOCOL}}）-> $TUNNEL_LOG"
  fi
}

start_unlocked() {
  start_devspace_unlocked || return $?
  start_cloudflared_unlocked
}

with_lock() {
  ensure_dirs
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock 9
    "$@"
    local rc=$?
    flock -u 9 || true
    exec 9>&-
    return "$rc"
  fi

  local tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    tries=$((tries + 1))
    [ "$tries" -lt 100 ] || { echo "错误：等待 DevSpace 服务锁超时：$LOCK_DIR" >&2; return 1; }
    sleep 0.1
  done

  "$@"
  local rc=$?
  rmdir "$LOCK_DIR" 2>/dev/null || true
  return "$rc"
}

start() {
  with_lock start_unlocked
}

autostart_start_unlocked() {
  local started=0
  if [ "$DEVSPACE_AUTOSTART" = "1" ]; then
    start_devspace_unlocked || return $?
    started=1
  fi
  if [ "$CLOUDFLARED_AUTOSTART" = "1" ]; then
    start_cloudflared_unlocked || return $?
    started=1
  fi
  [ "$started" -eq 1 ] || echo "DevSpace 与 cloudflared 的开机自启动均已关闭"
}

autostart_start() { with_lock autostart_start_unlocked; }

start_devspace() { with_lock start_devspace_unlocked; }
start_cloudflared() { with_lock start_cloudflared_unlocked; }

stop_pid_file() {
  local name="$1" file="$2" pat="$3" pid tries=0
  pid_matches "$file" "$pat" || { rm -f "$file"; return 1; }

  pid="$(cat "$file")"
  kill -TERM "$pid" 2>/dev/null || true

  while kill -0 "$pid" 2>/dev/null && [ "$tries" -lt 30 ]; do
    tries=$((tries + 1))
    sleep 0.1
  done

  kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
  rm -f "$file"
  echo "$name 已停止（PID ${pid}）"
}

kill_matching() {
  local name="$1" pat="$2" found=1 pid
  for pid in $(pgrep -f "$pat" 2>/dev/null); do
    [ "$pid" = "$$" ] && continue
    [ "$pid" = "$PPID" ] && continue
    kill -TERM "$pid" 2>/dev/null || true
    found=0
  done
  [ "$found" -eq 0 ] && echo "$name 已停止（兼容旧版进程扫描）"
  return "$found"
}

stop_unlocked() {
  local stopped=1
  stop_pid_file "devspace serve" "$SERVE_PID_FILE" "$SERVE_PAT" && stopped=0 || true
  stop_pid_file "cloudflared 隧道" "$TUNNEL_PID_FILE" "$TUNNEL_PAT" && stopped=0 || true
  kill_matching "devspace serve" "$SERVE_PAT" && stopped=0 || true
  kill_matching "cloudflared 隧道" "$TUNNEL_PAT" && stopped=0 || true
  [ "$stopped" -eq 0 ] || echo "DevSpace MCP / cloudflared 均未运行"
}

stop_devspace_unlocked() {
  stop_pid_file "devspace serve" "$SERVE_PID_FILE" "$SERVE_PAT" || kill_matching "devspace serve" "$SERVE_PAT" || echo "devspace serve 未运行"
}

stop_cloudflared_unlocked() {
  stop_pid_file "cloudflared 隧道" "$TUNNEL_PID_FILE" "$TUNNEL_PAT" || kill_matching "cloudflared 隧道" "$TUNNEL_PAT" || echo "cloudflared 隧道未运行"
}

stop() {
  with_lock stop_unlocked
}

stop_devspace() { with_lock stop_devspace_unlocked; }
stop_cloudflared() { with_lock stop_cloudflared_unlocked; }

status_one() {
  local name="$1" file="$2" pat="$3" pid
  if pid_matches "$file" "$pat"; then
    echo "$name: 运行中（PID $(cat "$file")）"
    return 0
  fi
  pid="$(find_matching_pid "$pat")"
  if [ -n "$pid" ]; then
    echo "$name: 运行中（兼容检测 PID ${pid}）"
    return 0
  fi
  echo "$name: 未运行"
  return 1
}

status() {
  echo "--- 进程 ---"
  status_one "devspace serve" "$SERVE_PID_FILE" "$SERVE_PAT" || true
  status_one "cloudflared tunnel" "$TUNNEL_PID_FILE" "$TUNNEL_PAT" || true

  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:7676/mcp 2>/dev/null || true)"
  echo "--- 本地 http://127.0.0.1:7676/mcp ---"
  [ -z "$code" ] && echo "不可达" || echo "HTTP ${code}（401 也表示服务已到达）"

  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "https://$PUBLIC_HOST/mcp" 2>/dev/null || true)"
  echo "--- 公网 https://$PUBLIC_HOST/mcp ---"
  [ -z "$code" ] && echo "不可达" || echo "HTTP ${code}（401 也表示隧道已到达）"

  echo "--- 配置 ---"
  echo "HOME: $RUN_HOME"
  echo "workdir: $WORKDIR"
  echo "devspace: $DEVSPACE_BIN"
  echo "cloudflared: $CLOUDFLARED_BIN"
  echo "cloudflared protocol: ${CLOUDFLARED_PROTOCOL:-auto}"
  echo "cloudflared config: $CLOUDFLARED_CONFIG"
  echo "platform: $OS"
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  restart) stop; sleep 1; start ;;
  start-devspace) start_devspace ;;
  stop-devspace) stop_devspace ;;
  restart-devspace) stop_devspace; sleep 1; start_devspace ;;
  start-cloudflared) start_cloudflared ;;
  stop-cloudflared) stop_cloudflared ;;
  restart-cloudflared) stop_cloudflared; sleep 1; start_cloudflared ;;
  autostart-start) autostart_start ;;
  status) status ;;
  token) ensure_token; cat "$TOKEN_FILE"; echo ;;
  *) echo "usage: $0 {start|stop|restart|start-devspace|stop-devspace|restart-devspace|start-cloudflared|stop-cloudflared|restart-cloudflared|autostart-start|status|token}" >&2; exit 1 ;;
esac
