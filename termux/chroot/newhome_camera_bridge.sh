#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC_DIR="$SCRIPT_DIR/newhome-camera-bridge"
BIN=${NEWHOME_CAMERA_BIN:-/usr/local/bin/newhome-camera-pipewire}
CAMERA=${NEWHOME_CAMERA_INDEX:-0}
WIDTH=${NEWHOME_CAMERA_WIDTH:-1280}
HEIGHT=${NEWHOME_CAMERA_HEIGHT:-720}
PACKAGE=com.example.customlauncher
PERMISSION_ACTIVITY="$PACKAGE/.camera.CameraBridgePermissionActivity"
SERVICE="$PACKAGE/.camera.CameraBridgeService"
PID_FILE=/tmp/newhome-camera-pipewire.pid
LOG_FILE=/tmp/newhome-camera-pipewire.log
PIPEWIRE_LOG=/tmp/newhome-pipewire.log

log() { printf '[newhome-camera] %s\n' "$*" >&2; }
fail() { log "ERROR: $*"; exit 1; }

find_android_root() {
    local pid
    pid=$(ps -eo pid,args | awk '/\/data\/data\/com\.termux\/files\/usr\/bin\/(bash|zsh)/ && !/awk/ {print $1; exit}')
    if [ -z "${pid:-}" ]; then
        pid=$(pgrep -xo com.termux 2>/dev/null || true)
    fi
    [ -n "${pid:-}" ] || return 1
    local root="/proc/$pid/root"
    [ -x "$root/system/bin/am" ] || return 1
    printf '%s\n' "$root"
}

android_am() {
    local root
    root=$(find_android_root) || fail "cannot locate Android /system through a Termux host process"
    chroot "$root" /system/bin/am "$@"
}

ensure_pipewire_runtime() {
    if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    fi
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
}

ensure_pipewire() {
    command -v pipewire >/dev/null 2>&1 || fail "install pipewire"
    command -v pw-cli >/dev/null 2>&1 || fail "install pipewire-bin"
    ensure_pipewire_runtime
    if pw-cli info 0 >/dev/null 2>&1; then
        return 0
    fi

    log "starting PipeWire core in XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
    nohup setsid pipewire </dev/null >>"$PIPEWIRE_LOG" 2>&1 &
    for _ in {1..50}; do
        if pw-cli info 0 >/dev/null 2>&1; then
            log "PipeWire core is ready"
            return 0
        fi
        sleep 0.1
    done
    tail -40 "$PIPEWIRE_LOG" >&2 2>/dev/null || true
    fail "PipeWire core did not become ready"
}

ensure_binary() {
    if [ -x "$BIN" ]; then return 0; fi
    command -v pkg-config >/dev/null 2>&1 || fail "install build-essential pkg-config libpipewire-0.3-dev"
    pkg-config --exists libpipewire-0.3 || fail "install libpipewire-0.3-dev"
    log "building PipeWire bridge"
    make -C "$SRC_DIR"
    install -Dm755 "$SRC_DIR/newhome-camera-pipewire" "$BIN"
}

start_android() {
    log "starting NewHome camera permission/FGS entry"
    android_am start --user 0 -n "$PERMISSION_ACTIVITY" >/dev/null
}

running_pid() {
    if [ -r "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            printf '%s\n' "$pid"
            return 0
        fi
    fi
    return 1
}

start_daemon() {
    ensure_pipewire
    ensure_binary
    if pid=$(running_pid); then
        log "already running pid=$pid"
        return 0
    fi
    start_android
    log "starting PipeWire source camera=$CAMERA size=${WIDTH}x${HEIGHT}"
    nohup "$BIN" --camera "$CAMERA" --width "$WIDTH" --height "$HEIGHT" \
        >>"$LOG_FILE" 2>&1 &
    echo $! >"$PID_FILE"
    log "pid=$! log=$LOG_FILE"
}

stop_all() {
    if pid=$(running_pid); then
        kill "$pid" 2>/dev/null || true
        for _ in {1..30}; do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -KILL "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
    pkill -x newhome-camera-pipewire 2>/dev/null || true
    android_am stopservice --user 0 -n "$SERVICE" >/dev/null 2>&1 || true
    # PipeWire is intentionally left alive: other Linux applications may use it.
}

case "${1:-start}" in
    build)
        ensure_binary
        ;;
    android|permission)
        start_android
        ;;
    start|daemon)
        start_daemon
        ;;
    foreground|fg)
        ensure_pipewire
        ensure_binary
        start_android
        log "foreground PipeWire source camera=$CAMERA size=${WIDTH}x${HEIGHT}"
        exec "$BIN" --camera "$CAMERA" --width "$WIDTH" --height "$HEIGHT"
        ;;
    status)
        ensure_pipewire_runtime
        printf 'PipeWire: %s\n' "$(pw-cli info 0 >/dev/null 2>&1 && echo running || echo stopped)"
        if pid=$(running_pid); then
            echo "Camera bridge: running pid=$pid"
            command -v pw-cli >/dev/null 2>&1 && pw-cli ls Node 2>/dev/null | grep -A8 -B2 -F 'newhome.camera' || true
        else
            echo "Camera bridge: stopped"
            exit 1
        fi
        ;;
    stop)
        stop_all
        ;;
    *)
        echo "usage: $0 {start|foreground|stop|status|build|permission}" >&2
        exit 2
        ;;
esac
