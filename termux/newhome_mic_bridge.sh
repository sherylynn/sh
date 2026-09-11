#!/bin/bash
set -u

HOST=127.0.0.1
PORT=${NEWHOME_MIC_PORT:-4714}
SOURCE_NAME=NewHomeMic
STATE_DIR=/tmp/newhome-mic-bridge
PID_FILE=$STATE_DIR/client.pid
MODULE_FILE=$STATE_DIR/module.id
LOG_FILE=$STATE_DIR/client.log
DEFAULT_SOURCE_FILE=$STATE_DIR/previous-default-source
PULSE_FIFO=/data/data/com.termux/files/usr/tmp/newhome-mic-bridge.pcm
CLIENT_FIFO=
CLIPBOARD_BRIDGE=/root/sh/termux/chroot/newhome_clipboard_bridge.py
CLIPBOARD_LOG=/tmp/newhome-clipboard-bridge-start.log

log() { printf '[newhome-mic] %s\n' "$*"; }
die() { printf '[newhome-mic] ERROR: %s\n' "$*" >&2; exit 1; }

module_id() {
    pactl list short modules 2>/dev/null |
        awk -v source="$SOURCE_NAME" '$2=="module-pipe-source" && $0 ~ "source_name=" source {print $1; exit}'
}

client_running() {
    [ -f "$PID_FILE" ] || return 1
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null) || return 1
    kill -0 "$pid" 2>/dev/null
}

clipboard_running() {
    pgrep -f '^python3 /root/sh/termux/chroot/newhome_clipboard_bridge.py$' >/dev/null 2>&1 ||
        pgrep -f '^/usr/bin/python3 /root/sh/termux/chroot/newhome_clipboard_bridge.py$' >/dev/null 2>&1
}

start_clipboard_bridge() {
    # This helper is also called by non-X11 Linux applications. Clipboard sync is
    # meaningful only when an X display exists; XFCE autostart covers later sessions.
    [ -n "${DISPLAY:-}" ] || { log "剪贴板桥未启动：DISPLAY 未设置"; return 0; }
    [ -f "$CLIPBOARD_BRIDGE" ] || { log "剪贴板桥未启动：缺少 $CLIPBOARD_BRIDGE"; return 0; }
    command -v python3 >/dev/null 2>&1 || { log "剪贴板桥未启动：缺少 python3"; return 0; }
    command -v xclip >/dev/null 2>&1 || {
        log "剪贴板桥未启动：缺少 xclip；请运行 bash /root/sh/debian/termux_chroot_desktop_setup.sh"
        return 0
    }
    if clipboard_running; then
        return 0
    fi
    nohup python3 "$CLIPBOARD_BRIDGE" </dev/null >"$CLIPBOARD_LOG" 2>&1 &
    log "已请求启动 Android/X11/VNC 剪贴板桥 (DISPLAY=$DISPLAY)"
}

stop_clipboard_bridge() {
    pkill -f '^python3 /root/sh/termux/chroot/newhome_clipboard_bridge.py$' 2>/dev/null || true
    pkill -f '^/usr/bin/python3 /root/sh/termux/chroot/newhome_clipboard_bridge.py$' 2>/dev/null || true
}

resolve_client_fifo() {
    local pulse_pid
    pulse_pid=$(ps -eo pid,args | awk '$2=="pulseaudio" {print $1; exit}')
    [ -n "$pulse_pid" ] || die "未找到 Termux PulseAudio 进程"
    CLIENT_FIFO=/proc/$pulse_pid/root$PULSE_FIFO
}

start_bridge() {
    start_clipboard_bridge || true
    command -v pactl >/dev/null 2>&1 || die "未找到 pactl"
    command -v python3 >/dev/null 2>&1 || die "未找到 python3"
    [ -n "${PULSE_SERVER:-}" ] || export PULSE_SERVER=tcp:127.0.0.1:4713
    if client_running; then
        pactl set-default-source "$SOURCE_NAME" >/dev/null 2>&1 || true
        log "桥接客户端已运行，并已设为默认麦克风：$SOURCE_NAME"
        return
    fi

    mkdir -p "$STATE_DIR"
    resolve_client_fifo
    rm -f "$CLIENT_FIFO"

    local id
    id=$(module_id)
    if [ -n "$id" ] && [ ! -p "$CLIENT_FIFO" ]; then
        pactl unload-module "$id" >/dev/null 2>&1 || true
        id=
    fi
    if [ -z "$id" ]; then
        id=$(pactl load-module module-pipe-source \
            source_name="$SOURCE_NAME" \
            source_properties=device.description=NewHome_Linux_Microphone \
            file="$PULSE_FIFO" format=s16le rate=16000 channels=1) ||
            die "无法创建 PulseAudio source"
    fi
    chmod 666 "$CLIENT_FIFO" || die "无法开放共享音频管道"
    printf '%s\n' "$id" > "$MODULE_FILE"

    local source_index
    source_index=$(pactl list short sources | awk -v source="$SOURCE_NAME" '$2==source {print $1; exit}')
    [ -n "$source_index" ] || die "无法取得 PulseAudio source 编号"
    if [ ! -f "$DEFAULT_SOURCE_FILE" ]; then
        pactl get-default-source > "$DEFAULT_SOURCE_FILE" 2>/dev/null || true
    fi
    pactl set-default-source "$SOURCE_NAME" || die "无法把 $SOURCE_NAME 设为默认麦克风"

    nohup python3 - "$HOST" "$PORT" "$CLIENT_FIFO" "$source_index" >"$LOG_FILE" 2>&1 <<'PY' &
import socket
import subprocess
import sys
import time

host, port, fifo, source_index = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]

def source_is_in_use():
    result = subprocess.run(
        ["pactl", "list", "short", "source-outputs"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    return any(
        len(fields := line.split()) >= 2 and fields[1] == source_index
        for line in result.stdout.splitlines()
    )

while True:
    if not source_is_in_use():
        time.sleep(0.25)
        continue
    # A source-output now exists: a Linux application is actively recording.
    with open(fifo, "wb", buffering=0) as output:
        try:
            with socket.create_connection((host, port), timeout=5) as sock:
                sock.sendall(b"START\n")
                header = bytearray()
                while not header.endswith(b"\n") and len(header) < 256:
                    chunk = sock.recv(1)
                    if not chunk:
                        raise RuntimeError("NewHome closed before protocol response")
                    header.extend(chunk)
                response = header.decode("utf-8", "replace").strip()
                if response != "OK PCM_S16LE 16000 1":
                    raise RuntimeError(f"NewHome rejected recording: {response}")
                sock.settimeout(0.25)
                while source_is_in_use():
                    try:
                        chunk = sock.recv(32768)
                    except socket.timeout:
                        continue
                    if not chunk:
                        break
                    output.write(chunk)
        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as exc:
            print(f"NewHome microphone session failed: {exc}", file=sys.stderr, flush=True)
            time.sleep(1)
PY
    local pid=$!
    printf '%s\n' "$pid" > "$PID_FILE"
    sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then
        cat "$LOG_FILE" >&2
        stop_bridge >/dev/null 2>&1 || true
        die "无法连接 NewHome 麦克风桥；请确认新版 App 已启动且录音权限已允许"
    fi
    log "录音已启动：$SOURCE_NAME (s16le/16000Hz/mono)，client PID=$pid"
}

stop_bridge() {
    stop_clipboard_bridge
    if client_running; then
        local pid
        pid=$(cat "$PID_FILE")
        kill -TERM "$pid" 2>/dev/null || true
        for _ in {1..20}; do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
        done
        kill -KILL "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"

    local id
    id=$(module_id)
    [ -n "$id" ] && pactl unload-module "$id" >/dev/null 2>&1 || true
    local previous_default
    previous_default=$(cat "$DEFAULT_SOURCE_FILE" 2>/dev/null || true)
    if [ -n "$previous_default" ]; then
        pactl set-default-source "$previous_default" >/dev/null 2>&1 || true
    fi
    resolve_client_fifo 2>/dev/null || true
    [ -n "$CLIENT_FIFO" ] && rm -f "$CLIENT_FIFO"
    rm -f "$MODULE_FILE" "$DEFAULT_SOURCE_FILE"
    log "录音已停止，麦克风和 PulseAudio source 已释放；剪贴板桥已停止"
}

status_bridge() {
    printf 'Client: %s\n' "$(client_running && echo "running (PID $(cat "$PID_FILE"))" || echo stopped)"
    printf 'Clipboard bridge: %s\n' "$(clipboard_running && echo running || echo stopped)"
    local id
    id=$(module_id)
    printf 'PulseAudio source: %s\n' "$(if [ -n "$id" ]; then echo "loaded (module $id)"; else echo 'not loaded'; fi)"
    pactl list short sources 2>/dev/null | grep -F "$SOURCE_NAME" || true
    [ -f "$LOG_FILE" ] && tail -20 "$LOG_FILE"
    [ -f "$CLIPBOARD_LOG" ] && tail -10 "$CLIPBOARD_LOG"
}

case ${1:-status} in
    start) start_bridge ;;
    stop) stop_bridge ;;
    restart) stop_bridge; start_bridge ;;
    status) status_bridge ;;
    *) echo "Usage: $0 {start|stop|restart|status}"; exit 2 ;;
esac
