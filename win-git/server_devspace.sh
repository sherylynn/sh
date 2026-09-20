#!/usr/bin/env bash
# server_devspace.sh —— DevSpace MCP server + Cloudflare named tunnel service manager
#
# Desktop/autostart and init.d may both call "start". start is idempotent and
# serialized so both startup paths can safely coexist.
set -uo pipefail

if [ "$(id -u)" -eq 0 ]; then
  export HOME=/root
fi

NODE_BIN_DIR="$(dirname "$(command -v node 2>/dev/null)" 2>/dev/null || true)"
if [ ! -x "${NODE_BIN_DIR:-/nonexistent}/node" ]; then
  for _d in /root/tools/node/node-*/bin; do
    [ -x "$_d/node" ] && NODE_BIN_DIR="$_d" && break
  done
fi
export PATH="${NODE_BIN_DIR:-/usr/bin}:/root/tools/node-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin${PATH:+:$PATH}"

RUN_HOME="${DEVSPACE_HOME:-${HOME:-/root}}"
CONFIG_DIR="${DEVSPACE_CONFIG_DIR:-$RUN_HOME/.devspace}"
TOKEN_FILE="$CONFIG_DIR/owner-token"
SERVE_LOG="${DEVSPACE_SERVE_LOG:-/tmp/devspace-serve.log}"
TUNNEL_LOG="${DEVSPACE_TUNNEL_LOG:-/tmp/cloudflared-devspace.log}"
TUNNEL_NAME="${DEVSPACE_TUNNEL_NAME:-devspace}"
CLOUDFLARED_CONFIG="${CLOUDFLARED_CONFIG:-$RUN_HOME/.cloudflared/config.yml}"
WORKDIR="${DEVSPACE_WORKDIR:-$RUN_HOME/sh}"
DEVSPACE_BIN="${DEVSPACE_BIN:-$(command -v devspace 2>/dev/null || echo "$RUN_HOME/tools/node-global/bin/devspace")}"
LOCK_FILE="${DEVSPACE_LOCK_FILE:-/tmp/.devspace-service.lock}"
LOCK_DIR="${DEVSPACE_LOCK_DIR:-${LOCK_FILE}.d}"

SERVE_PAT="^node .*bin/devspace serve"
TUNNEL_PAT="^cloudflared tunnel .*run ${TUNNEL_NAME}"

ensure_token() {
  mkdir -p "$CONFIG_DIR"
  [ -s "$TOKEN_FILE" ] || openssl rand -base64 32 >"$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  if [ ! -s "$CONFIG_DIR/auth.json" ]; then
    printf '{\n  "ownerToken": "%s"\n}\n' "$(cat "$TOKEN_FILE")" >"$CONFIG_DIR/auth.json"
    chmod 600 "$CONFIG_DIR/auth.json"
  fi
}

start_unlocked() {
  ensure_token
  export DEVSPACE_OAUTH_OWNER_TOKEN="$(cat "$TOKEN_FILE")"

  if [ ! -x "$DEVSPACE_BIN" ]; then
    echo "错误：找不到 devspace 可执行文件（$DEVSPACE_BIN）" >&2
    return 1
  fi

  if pgrep -f "$SERVE_PAT" >/dev/null 2>&1; then
    echo "devspace serve 已在运行，本次不重复启动"
  else
    # Close the service-manager lock fd in the daemon. Otherwise the daemon
    # keeps flock alive after this manager exits and a second startup path can
    # block forever waiting for a lock that should already have been released.
    (cd "$WORKDIR" && setsid nohup "$DEVSPACE_BIN" serve </dev/null >"$SERVE_LOG" 2>&1 9>&- &)
    echo "devspace serve 已启动 -> $SERVE_LOG"
  fi

  if pgrep -f "$TUNNEL_PAT" >/dev/null 2>&1; then
    echo "cloudflared 隧道已在运行，本次不重复启动"
  else
    setsid nohup cloudflared tunnel --config "$CLOUDFLARED_CONFIG" run "$TUNNEL_NAME" </dev/null >"$TUNNEL_LOG" 2>&1 9>&- &
    echo "cloudflared 隧道已启动 -> $TUNNEL_LOG"
  fi
}

with_lock() {
  # Prefer flock when available. On minimal chroot images without util-linux,
  # fall back to an atomic mkdir lock so rc3 + desktop cannot race.
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock 9
    "$@"
    return
  fi

  local tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -ge 100 ]; then
      echo "错误：等待 DevSpace 服务锁超时：$LOCK_DIR" >&2
      return 1
    fi
    sleep 0.1
  done
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' RETURN
  "$@"
  rmdir "$LOCK_DIR" 2>/dev/null || true
  trap - RETURN
}

start() {
  # rc3 and desktop/autostart may race. Serialize the whole check-and-start
  # sequence; the second caller then observes the already-running processes.
  with_lock start_unlocked
}

kill_match() {
  local pat="$1" pid killed=0
  for pid in $(pgrep -f "$pat" 2>/dev/null); do
    [ "$pid" = "$$" ] && continue
    [ "$pid" = "$PPID" ] && continue
    kill -TERM "$pid" 2>/dev/null && killed=1
  done
  [ "$killed" = "1" ]
}

stop_unlocked() {
  kill_match "$SERVE_PAT" && echo "devspace serve 已停止" || echo "devspace serve 未在运行"
  kill_match "$TUNNEL_PAT" && echo "cloudflared 隧道已停止" || echo "cloudflared 隧道未在运行"
}

stop() {
  with_lock stop_unlocked
}

status() {
  echo "--- devspace serve ---"
  pgrep -af "$SERVE_PAT" || echo "  未运行"
  echo "--- cloudflared tunnel ---"
  pgrep -af "$TUNNEL_PAT" || echo "  未运行"

  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:7676/mcp 2>/dev/null || echo 000)"
  echo "--- 本地 127.0.0.1:7676/mcp ---"
  [ "$code" = "000" ] && echo "  不可达（serve 未起）" || echo "  HTTP $code（401=正常）"

  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "https://${PUBLIC_HOST:-devspace.sherylynn.win}/mcp" 2>/dev/null || echo 000)"
  echo "--- 公网 https://${PUBLIC_HOST:-devspace.sherylynn.win}/mcp ---"
  [ "$code" = "000" ] && echo "  不可达（隧道未连上）" || echo "  HTTP $code（401=隧道通）"
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  restart) stop; sleep 1; start ;;
  status) status ;;
  token) ensure_token; cat "$TOKEN_FILE"; echo ;;
  *) echo "usage: $0 {start|stop|restart|status|token}"; exit 1 ;;
esac
