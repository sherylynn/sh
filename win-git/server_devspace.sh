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
# cloudflared 本地 metrics 端点：判定隧道有没有真的注册到 Cloudflare edge 的
# 唯一可靠本地判据。进程存活 != 隧道可用 —— 进程在跑但 0 个边缘连接时，
# 公网会返回 530，只看 pgrep 永远发现不了。
# 必须显式绑定：不指定时 cloudflared 会在 20241-20245 里挑一个、都占用就随机，
# 探测端口漂移会让连通性判定静默失效。
CLOUDFLARED_METRICS="${CLOUDFLARED_METRICS:-127.0.0.1:20241}"
METRICS_CANDIDATES="$CLOUDFLARED_METRICS 127.0.0.1:20241 127.0.0.1:20242 127.0.0.1:20243 127.0.0.1:20244 127.0.0.1:20245"
METRICS_TIMEOUT="${METRICS_TIMEOUT:-3}"
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
# mkdir 回退锁在 macOS 上没有失效回收：持有者被 kill/Ctrl-C 后目录会永久留下，
# 之后所有 start/stop/restart 都会等满 10s 后报「等待服务锁超时」。
# 因此记录持有者 PID，并对无主的目录按年龄判定为僵尸锁。
LOCK_WAIT_TRIES="${DEVSPACE_LOCK_TRIES:-100}"
LOCK_STALE_SECONDS="${DEVSPACE_LOCK_STALE:-120}"
LOCK_HELD=0

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
    # metrics 只能用环境变量传：`--metrics` 是 cloudflared 的全局 flag，
    # 放在 `tunnel run` 之后会被判为 "flag provided but not defined: -metrics"
    # 并打印帮助直接退出（哪怕 run --help 里列出了它）。
    case "$CLOUDFLARED_METRICS" in
      ""|auto|off) ;;
      *) export TUNNEL_METRICS="$CLOUDFLARED_METRICS" ;;
    esac
    start_background "$TUNNEL_PID_FILE" "$TUNNEL_LOG" "$CLOUDFLARED_BIN" "${args[@]}"
    unset TUNNEL_METRICS
    echo "cloudflared 隧道已启动（PID $(cat "$TUNNEL_PID_FILE")${CLOUDFLARED_PROTOCOL:+, protocol=${CLOUDFLARED_PROTOCOL}}${CLOUDFLARED_METRICS:+, metrics=${CLOUDFLARED_METRICS}}）-> $TUNNEL_LOG"
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

  acquire_lock_dir || return 1
  # 异常中断（Ctrl-C / kill / launchd 收割）时也要把锁交还，否则会留下僵尸锁。
  trap 'release_lock_dir; exit 1' INT TERM HUP
  trap 'release_lock_dir' EXIT

  "$@"
  local rc=$?
  release_lock_dir
  trap - EXIT INT TERM HUP
  return "$rc"
}

lock_dir_age_seconds() {
  local mtime now
  mtime="$(stat -f %m "$LOCK_DIR" 2>/dev/null || stat -c %Y "$LOCK_DIR" 2>/dev/null || true)"
  [ -n "$mtime" ] || return 1
  now="$(date +%s)"
  printf '%s' "$((now - mtime))"
}

release_lock_dir() {
  [ "$LOCK_HELD" = 1 ] || return 0
  rm -rf "$LOCK_DIR" 2>/dev/null || true
  LOCK_HELD=0
}

acquire_lock_dir() {
  local tries=0 owner age
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    owner="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
      echo "清理失效服务锁（持有进程 ${owner} 已不存在）：$LOCK_DIR" >&2
      rm -rf "$LOCK_DIR"
      continue
    fi
    if [ -z "$owner" ]; then
      # 空目录：可能卡在 mkdir 与写 pid 之间。按目录年龄判定，超龄视为僵尸锁。
      age="$(lock_dir_age_seconds || echo 0)"
      if [ "$age" -gt "$LOCK_STALE_SECONDS" ]; then
        echo "清理僵尸服务锁（无持有者且已存在 ${age}s）：$LOCK_DIR" >&2
        rm -rf "$LOCK_DIR"
        continue
      fi
    fi
    tries=$((tries + 1))
    [ "$tries" -lt "$LOCK_WAIT_TRIES" ] || { echo "错误：等待 DevSpace 服务锁超时：$LOCK_DIR" >&2; return 1; }
    sleep 0.1
  done

  printf '%s\n' "$$" >"$LOCK_DIR/pid" 2>/dev/null || true
  LOCK_HELD=1
  return 0
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

# --- 隧道真实连通性 ---------------------------------------------------------
# 只看进程存活是不够的。cloudflared 自带的本地 metrics 端点零网络依赖且权威：
#   GET /ready -> 200 {"status":200,"readyConnections":N}  已注册到 edge
#              -> 503 {"status":503,"readyConnections":0}  未注册（公网 530）
metrics_base() {
  local candidate
  for candidate in $METRICS_CANDIDATES; do
    [ -n "$candidate" ] || continue
    if curl -sS -o /dev/null --max-time 1 "http://$candidate/ready" 2>/dev/null; then
      printf 'http://%s' "$candidate"
      return 0
    fi
  done
  return 1
}

tunnel_ready_body() {
  local base
  base="$(metrics_base)" || return 1
  curl -sS --max-time "$METRICS_TIMEOUT" "$base/ready" 2>/dev/null
}

serve_pid() {
  if pid_matches "$SERVE_PID_FILE" "$SERVE_PAT"; then
    cat "$SERVE_PID_FILE"
    return 0
  fi
  find_matching_pid "$SERVE_PAT"
}

tunnel_pid() {
  if pid_matches "$TUNNEL_PID_FILE" "$TUNNEL_PAT"; then
    cat "$TUNNEL_PID_FILE"
    return 0
  fi
  find_matching_pid "$TUNNEL_PAT"
}

# connected | disconnected | stopped | unknown
tunnel_state() {
  [ -n "$(tunnel_pid)" ] || { echo stopped; return 0; }
  local body
  body="$(tunnel_ready_body)" || { echo unknown; return 0; }
  case "$body" in
    *'"readyConnections":0'*) echo disconnected ;;
    *'"readyConnections":'*)  echo connected ;;
    *)                        echo unknown ;;
  esac
}

tunnel_connections() {
  local body
  body="$(tunnel_ready_body)" || { printf '0'; return 0; }
  printf '%s' "$body" | sed -n 's/.*"readyConnections":\([0-9][0-9]*\).*/\1/p' | head -1
}

tunnel_log_field() {
  local key="$1"
  tail -n 400 "$TUNNEL_LOG" 2>/dev/null \
    | grep -o "${key}=[A-Za-z0-9._:-]*" | sed "s/^${key}=//" | tail -1
}

tunnel_edges() {
  tail -n 400 "$TUNNEL_LOG" 2>/dev/null \
    | grep -o 'location=[A-Za-z0-9]*' | sed 's/^location=//' | awk '!seen[$0]++' \
    | tail -2 | tr '\n' ',' | sed 's/,$//'
}

tunnel_last_error() {
  tail -n 200 "$TUNNEL_LOG" 2>/dev/null \
    | grep ' ERR ' | tail -1 \
    | sed -n 's/.*error="\([^"]*\)".*/\1/p'
}

tunnel_error_hint() {
  local err
  err="$(tunnel_last_error)"
  [ -n "$err" ] || return 0
  case "$err" in
    *quic*) printf '%s' '疑似 QUIC(UDP) 被本机代理/防火墙吞掉，试 CLOUDFLARED_PROTOCOL=http2' ;;
    *'TLS handshake'*) printf '%s' "edge TLS 握手失败：$(printf '%s' "$err" | cut -c1-80)（常见于 fake-IP/TUN 代理或本地 DNS 缓存过期，重启隧道可重新解析）" ;;
    *) printf '%s' "$err" ;;
  esac
}

# 人类可读的一行连通性描述
tunnel_info() {
  local state n edges proto err
  state="$(tunnel_state)"
  case "$state" in
    connected)
      n="$(tunnel_connections)"
      edges="$(tunnel_edges)"
      proto="$(tunnel_log_field protocol)"
      printf '已连接 Cloudflare edge（%s 个边缘连接' "$n"
      [ -n "$edges" ] && printf '，%s' "$edges"
      [ -n "$proto" ] && printf '，%s' "$proto"
      printf '）\n'
      ;;
    disconnected)
      printf '未连接 Cloudflare edge（进程在运行，但 0 个边缘连接，公网会返回 530）'
      err="$(tunnel_error_hint)"
      [ -n "$err" ] && printf '；最近错误：%s' "$err"
      printf '\n'
      ;;
    stopped)
      printf '未运行\n'
      ;;
    *)
      printf '未知（隧道进程在运行，但 metrics 端点 %s 不可达；若刚启动则可能仍在初始化）\n' "$CLOUDFLARED_METRICS"
      ;;
  esac
}

# 供托盘解析的机器可读状态（无网络请求，毫秒级返回）
states() {
  local pid state n
  pid="$(serve_pid)"
  if [ -n "$pid" ]; then
    echo "serve=running"
    echo "serve_pid=$pid"
  else
    echo "serve=stopped"
    echo "serve_pid="
  fi

  pid="$(tunnel_pid)"
  if [ -n "$pid" ]; then
    echo "tunnel_pid=$pid"
  else
    echo "tunnel_pid="
  fi

  state="$(tunnel_state)"
  echo "tunnel=$state"
  if [ "$state" = "connected" ]; then
    n="$(tunnel_connections)"
    echo "tunnel_connections=${n:-0}"
    echo "tunnel_edges=$(tunnel_edges)"
    echo "tunnel_protocol=$(tunnel_log_field protocol)"
    echo "tunnel_error="
  else
    echo "tunnel_connections=0"
    echo "tunnel_edges="
    echo "tunnel_protocol="
    echo "tunnel_error=$(tunnel_last_error)"
  fi
}

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

  echo "--- 隧道连通性 ---"
  echo "cloudflared -> Cloudflare edge: $(tunnel_info | tr -d '\n')"

  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:7676/mcp 2>/dev/null || true)"
  echo "--- 本地 http://127.0.0.1:7676/mcp ---"
  case "$code" in
    ""|000) echo "不可达（devspace serve 未监听）" ;;
    401|200) echo "HTTP ${code}（服务已到达）" ;;
    *) echo "HTTP ${code}" ;;
  esac

  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time "${PUBLIC_PROBE_TIMEOUT:-20}" "https://$PUBLIC_HOST/mcp" 2>/dev/null || true)"
  echo "--- 公网 https://$PUBLIC_HOST/mcp ---"
  case "$code" in
    ""|000) echo "不可达（连接失败或超时）" ;;
    530) echo "HTTP 530（Cloudflare 侧没有可用隧道连接 —— 隧道未连上 edge）" ;;
    401|200) echo "HTTP ${code}（隧道已到达，401 是正常的未授权握手）" ;;
    *) echo "HTTP ${code}" ;;
  esac

  echo "--- 配置 ---"
  echo "HOME: $RUN_HOME"
  echo "workdir: $WORKDIR"
  echo "devspace: $DEVSPACE_BIN"
  echo "cloudflared: $CLOUDFLARED_BIN"
  echo "cloudflared protocol: ${CLOUDFLARED_PROTOCOL:-auto}"
  echo "cloudflared metrics: ${CLOUDFLARED_METRICS:-off}"
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
  states) states ;;
  tunnel-state) tunnel_state ;;
  tunnel-info) tunnel_info ;;
  token) ensure_token; cat "$TOKEN_FILE"; echo ;;
  *) echo "usage: $0 {start|stop|restart|start-devspace|stop-devspace|restart-devspace|start-cloudflared|stop-cloudflared|restart-cloudflared|autostart-start|status|states|tunnel-state|tunnel-info|token}" >&2; exit 1 ;;
esac
