#!/data/data/com.termux/files/usr/bin/bash

# runit-managed Termux:X11 service. Keep the X server as this service's child,
# wait for its socket, then bring up the Android Activity so it can connect and
# apply framebuffer preferences.

set -u

DISPLAY_NUMBER=1
X11_SOCKET="${TMPDIR}/.X11-unix/X${DISPLAY_NUMBER}"
STARTUP_LOG="${HOME}/.termux-x11-startup.log"
READY_FILE="${TMPDIR}/.termux-x11-ready"
X11_PID=""

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$STARTUP_LOG"
}

cleanup() {
    rm -f "$READY_FILE"
    if [ -n "$X11_PID" ] && kill -0 "$X11_PID" 2>/dev/null; then
        kill "$X11_PID" 2>/dev/null || true
        wait "$X11_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM HUP

mkdir -p "$(dirname "$X11_SOCKET")"
rm -f "$READY_FILE"

# A socket left by a previous untrapped service must not be mistaken for the
# new child becoming ready. The orchestrator stops/kills the old instance
# before `sv up`; refuse to compete if one is nevertheless still alive.
existing_pid=$(pgrep -f 'termux-x11 com\.termux\.x11 :1' 2>/dev/null | head -1 || true)
if [ -n "$existing_pid" ]; then
    log "refusing to start while another :1 server is alive (pid=${existing_pid})"
    exit 1
fi
rm -f "$X11_SOCKET"
log "starting Termux:X11 server on :${DISPLAY_NUMBER}"

export XDG_RUNTIME_DIR="${TMPDIR}"
termux-x11 ":${DISPLAY_NUMBER}" -ac +extension DPMS -dpi 100 >>"$STARTUP_LOG" 2>&1 &
X11_PID=$!
log "termux-x11 pid=${X11_PID}; waiting for ${X11_SOCKET}"

socket_ready=false
for _ in $(seq 1 150); do
    if ! kill -0 "$X11_PID" 2>/dev/null; then
        wait "$X11_PID" 2>/dev/null
        rc=$?
        log "termux-x11 exited before its socket became ready (rc=${rc})"
        exit "$rc"
    fi
    if [ -S "$X11_SOCKET" ]; then
        socket_ready=true
        break
    fi
    sleep 0.1
done

if [ "$socket_ready" != true ]; then
    log "timed out waiting for X socket: ${X11_SOCKET}"
    exit 1
fi
log "X socket is ready"

activity_ok=false
for attempt in 1 2 3; do
    # Android may silently decline a background Activity start from the Termux
    # app UID. The existing tsu/sudo root path receives a real wait result and
    # reliably brings the Activity to the foreground.
    activity_output=$(sudo /system/bin/am start -W --user 0 \
        -n com.termux.x11/com.termux.x11.MainActivity 2>&1)
    activity_rc=$?
    printf '%s\n' "$activity_output" >>"$STARTUP_LOG"
    if [ "$activity_rc" -eq 0 ] && printf '%s\n' "$activity_output" | grep -q '^Status: ok$'; then
        activity_ok=true
        break
    fi
    log "Activity launch attempt ${attempt} failed (rc=${activity_rc})"
    sleep 0.5
done

if [ "$activity_ok" != true ]; then
    log "Termux:X11 Activity did not start; leaving X server running for diagnosis"
    wait "$X11_PID"
    exit $?
fi

if ! kill -0 "$X11_PID" 2>/dev/null; then
    wait "$X11_PID" 2>/dev/null
    rc=$?
    log "termux-x11 exited while the Activity was starting (rc=${rc})"
    exit "$rc"
fi

termux-wake-lock >>"$STARTUP_LOG" 2>&1 || true
printf 'pid=%s started=%s\n' "$X11_PID" "$(date +%s)" >"$READY_FILE"
log "Termux:X11 Activity started and service is ready"

wait "$X11_PID"
exit $?
