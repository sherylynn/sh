#!/data/data/com.termux/files/usr/bin/bash
set -u

PULSE_SERVER_ADDR="${PULSE_SERVER:-tcp:127.0.0.1:4713}"
NEWHOME_HOST="${NEWHOME_PLAYBACK_HOST:-127.0.0.1}"
NEWHOME_PORT="${NEWHOME_PLAYBACK_PORT:-4716}"
SINK_NAME="${NEWHOME_PLAYBACK_SINK:-NewHomeSpeaker}"
STATE_DIR="${PREFIX}/var/run/newhome_playback_bridge"
FIFO="${PREFIX}/tmp/newhome-playback.pcm"
MODULE_ID_FILE="${STATE_DIR}/module_id"
PID_FILE="${STATE_DIR}/worker.pid"
PREVIOUS_DEFAULT_FILE="${STATE_DIR}/previous_default_sink"

log() { printf '[newhome-playback] %s\n' "$*"; }
warn() { printf '[newhome-playback] WARN: %s\n' "$*" >&2; }

pulse() {
  PULSE_SERVER="$PULSE_SERVER_ADDR" pactl "$@"
}

module_id() {
  pulse list short modules 2>/dev/null |
    awk -v sink="$SINK_NAME" '$2=="module-pipe-sink" && $0 ~ ("sink_name=" sink) {print $1; exit}'
}

worker_alive() {
  [ -f "$PID_FILE" ] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

read_ascii_line_fd() {
  local fd="$1" line
  IFS= read -r -u "$fd" line || return 1
  printf '%s\n' "${line%$'\r'}"
}

worker_loop() {
  trap 'exit 0' TERM INT
  while :; do
    if [ ! -p "$FIFO" ]; then
      sleep 0.2
      continue
    fi

    # Bash /dev/tcp keeps the local NewHome endpoint dependency-free.
    if ! exec 7<>"/dev/tcp/${NEWHOME_HOST}/${NEWHOME_PORT}" 2>/dev/null; then
      sleep 0.5
      continue
    fi

    printf 'START PCM_S16LE 48000 2\n' >&7 || {
      exec 7>&- 7<&-
      sleep 0.5
      continue
    }

    local response
    response="$(read_ascii_line_fd 7 2>/dev/null || true)"
    if [ "$response" != "OK PCM_S16LE 48000 2" ]; then
      exec 7>&- 7<&-
      sleep 0.5
      continue
    fi

    # module-pipe-sink is the writer; this blocks with essentially zero extra buffering.
    # A disconnected NewHome socket makes cat fail and the outer loop reconnects.
    cat "$FIFO" >&7 2>/dev/null || true
    exec 7>&- 7<&-
    sleep 0.2
  done
}

start_worker() {
  mkdir -p "$STATE_DIR"
  if worker_alive; then
    return 0
  fi
  rm -f "$PID_FILE"
  worker_loop </dev/null >/dev/null 2>&1 &
  printf '%s\n' "$!" >"$PID_FILE"
}

load_sink() {
  local existing
  existing="$(module_id)"
  if [ -n "$existing" ]; then
    printf '%s\n' "$existing" >"$MODULE_ID_FILE"
    return 0
  fi

  # Do not pre-create the FIFO. PulseAudio must create/open it from its own app-data
  # SELinux domain; the worker waits until it appears.
  rm -f "$FIFO"
  start_worker

  local id
  id="$(pulse load-module module-pipe-sink \
    sink_name="$SINK_NAME" \
    file="$FIFO" \
    format=s16le \
    rate=48000 \
    channels=2 2>/dev/null)" || {
      warn "module-pipe-sink 加载失败"
      return 1
    }
  printf '%s\n' "$id" >"$MODULE_ID_FILE"
}

start_bridge() {
  command -v pactl >/dev/null 2>&1 || {
    warn "缺少 pactl"
    return 1
  }
  mkdir -p "$STATE_DIR"

  local previous
  previous="$(pulse info 2>/dev/null | sed -n 's/^Default Sink: //p' | head -n1)"
  if [ -n "$previous" ] && [ "$previous" != "$SINK_NAME" ]; then
    printf '%s\n' "$previous" >"$PREVIOUS_DEFAULT_FILE"
  fi

  load_sink || return 1
  start_worker
  pulse set-default-sink "$SINK_NAME" >/dev/null 2>&1 || true
  log "默认 sink=$SINK_NAME -> NewHome ${NEWHOME_HOST}:${NEWHOME_PORT}"
}

stop_bridge() {
  if worker_alive; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    sleep 0.1
  fi
  rm -f "$PID_FILE"

  if [ -f "$PREVIOUS_DEFAULT_FILE" ]; then
    local previous
    previous="$(cat "$PREVIOUS_DEFAULT_FILE" 2>/dev/null || true)"
    [ -n "$previous" ] && pulse set-default-sink "$previous" >/dev/null 2>&1 || true
    rm -f "$PREVIOUS_DEFAULT_FILE"
  fi

  local id
  id="$(module_id)"
  if [ -z "$id" ] && [ -f "$MODULE_ID_FILE" ]; then
    id="$(cat "$MODULE_ID_FILE" 2>/dev/null || true)"
  fi
  [ -z "$id" ] || pulse unload-module "$id" >/dev/null 2>&1 || true
  rm -f "$MODULE_ID_FILE" "$FIFO"
  log "NewHome speaker bridge stopped"
}

status_bridge() {
  local id default_sink pid
  id="$(module_id)"
  default_sink="$(pulse info 2>/dev/null | sed -n 's/^Default Sink: //p' | head -n1)"
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  printf 'sink=%s module=%s default=%s worker=%s fifo=%s endpoint=%s:%s\n' \
    "$SINK_NAME" "${id:-none}" "${default_sink:-unknown}" \
    "${pid:-none}" "$(if [ -p "$FIFO" ]; then echo ready; else echo missing; fi)" \
    "$NEWHOME_HOST" "$NEWHOME_PORT"
}

case "${1:-status}" in
  start) start_bridge ;;
  stop) stop_bridge ;;
  restart) stop_bridge; start_bridge ;;
  status) status_bridge ;;
  worker) worker_loop ;;
  *) echo "usage: $0 {start|stop|restart|status}" >&2; exit 2 ;;
esac
