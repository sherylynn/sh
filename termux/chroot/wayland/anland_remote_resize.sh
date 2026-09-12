#!/bin/bash
# Apply a noVNC framebuffer size to Anland and rebuild only the display chain.
# The Debian mount/container is deliberately left intact.
set -euo pipefail

RESOLUTION=${1:-}
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SESSION_SCRIPT="$SCRIPT_DIR/start_labwc_anland.sh"
ANLAND_PACKAGE=com.anland.termux
ANLAND_ACTIVITY=com.anland.termux/.MainActivity
ANLAND_SOCKET=/data/data/com.termux/files/usr/tmp/anland/display_daemon.sock
LOG_FILE=/tmp/newhome-anland-resize.log
LOCK_FILE=/tmp/newhome-anland-resize.lock

log() {
    printf 'time=%s %s\n' "$(date +%s)" "$*" | tee -a "$LOG_FILE"
}

fail() {
    log "ERROR: $*" >&2
    exit 1
}

[[ "$RESOLUTION" =~ ^[0-9]+x[0-9]+$ ]] || fail "invalid resolution: $RESOLUTION"
WIDTH=${RESOLUTION%x*}
HEIGHT=${RESOLUTION#*x}
(( WIDTH >= 320 && WIDTH <= 8192 && HEIGHT >= 240 && HEIGHT <= 8192 )) || \
    fail "resolution outside supported range: $RESOLUTION"

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

# A host Termux process gives this chroot a stable view of Android's /system and
# /data. Do not depend on the Anland process itself: it is replaced below.
TERMUX_PID=$(ps -eo pid,args | awk \
    '/\/data\/data\/com\.termux\/files\/usr\/bin\/(bash|zsh)/ && !/awk/ {print $1; exit}')
[ -n "$TERMUX_PID" ] || fail "cannot locate a host Termux process"
HOST_ROOT=/proc/$TERMUX_PID/root
[ -x "$HOST_ROOT/system/bin/am" ] || fail "Android activity manager is unavailable"

android() {
    local command=$1
    shift
    chroot "$HOST_ROOT" "/system/bin/$command" "$@"
}

PREF_FILE="$HOST_ROOT/data/user/0/$ANLAND_PACKAGE/shared_prefs/anland_settings.xml"
[ -f "$PREF_FILE" ] || fail "Anland preferences not found: $PREF_FILE"

read_int_pref() {
    local key=$1
    sed -n "s#.*<int name=\"$key\" value=\"\([0-9]*\)\" */>.*#\1#p" "$PREF_FILE" | head -1
}

# noVNC sends SetDesktopSize again after its XWayland connection reopens. Do
# not turn that acknowledgement into a permanent reconnect loop.
if [ "$(read_int_pref custom_width)" = "$WIDTH" ] && \
        [ "$(read_int_pref custom_height)" = "$HEIGHT" ] && \
        grep -q "set output mode ${WIDTH}x${HEIGHT}@" /tmp/newhome-wayland/weston.log 2>/dev/null && \
        pgrep -x labwc >/dev/null 2>&1; then
    log "Anland resolution already active: $RESOLUTION"
    exit 0
fi

# SharedPreferences are read only while MainActivity creates its native
# connection. Stop the consumer first, then update the two official Anland
# keys. Other Anland settings remain untouched.
android am force-stop --user 0 "$ANLAND_PACKAGE" >/dev/null 2>&1 || true

update_int_pref() {
    local key=$1 value=$2 temporary
    temporary=$(mktemp /tmp/anland-settings.XXXXXX)
    if grep -q "<int name=\"$key\"" "$PREF_FILE"; then
        sed "s#<int name=\"$key\" value=\"[0-9]*\" */>#<int name=\"$key\" value=\"$value\" />#" \
            "$PREF_FILE" >"$temporary"
    else
        sed "/<\/map>/i\\    <int name=\"$key\" value=\"$value\" />" \
            "$PREF_FILE" >"$temporary"
    fi
    # Overwrite the existing inode so Android's SELinux label is preserved.
    cat "$temporary" >"$PREF_FILE"
    rm -f "$temporary"
}

update_int_pref custom_width "$WIDTH"
update_int_pref custom_height "$HEIGHT"
chmod 600 "$PREF_FILE"
log "saved Anland resolution=$RESOLUTION"

# Anland 5.13.3 documents custom resolution as taking effect on the next
# connection. Its Weston backend cannot recover after only the Android consumer
# reconnects, so replace daemon + Weston + Labwc together, without touching the
# mounted container/rootfs.
pkill -TERM -x labwc >/dev/null 2>&1 || true
pkill -TERM -x weston >/dev/null 2>&1 || true
for _ in {1..50}; do
    if ! pgrep -x labwc >/dev/null 2>&1 && ! pgrep -x weston >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done
pkill -KILL -x labwc >/dev/null 2>&1 || true
pkill -KILL -x weston >/dev/null 2>&1 || true

PREFIX=/data/data/com.termux/files/usr
chroot "$HOST_ROOT" "$PREFIX/bin/env" -i \
    HOME=/data/data/com.termux/files/home PREFIX="$PREFIX" TMPDIR="$PREFIX/tmp" \
    PATH="$PREFIX/bin:/system/bin:/system/xbin" "$PREFIX/bin/bash" -lc \
    'pkill -TERM -x anland 2>/dev/null || true; sleep 0.2; pkill -KILL -x anland 2>/dev/null || true; rm -f "$PREFIX/tmp/anland/display_daemon.sock"; mkdir -p "$PREFIX/tmp/anland"; nohup anland --socket "$PREFIX/tmp/anland/display_daemon.sock" >"$PREFIX/tmp/anland/newhome-anland.log" 2>&1 </dev/null &'

for _ in {1..100}; do
    [ -S /tmp/anland/display_daemon.sock ] && break
    sleep 0.1
done
[ -S /tmp/anland/display_daemon.sock ] || fail "Anland daemon socket did not return"

nohup env NEWHOME_WAYLAND_MODE=${NEWHOME_WAYLAND_MODE:-auto} \
    /bin/bash "$SESSION_SCRIPT" >/tmp/newhome-wayland-session-supervisor.log 2>&1 </dev/null &
for _ in {1..120}; do
    if pgrep -x weston >/dev/null 2>&1 || pgrep -x labwc >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done

android am start --user 0 -n "$ANLAND_ACTIVITY" >/dev/null
for _ in {1..150}; do
    if grep -q "set output mode ${WIDTH}x${HEIGHT}@" /tmp/newhome-wayland/weston.log 2>/dev/null && \
            pgrep -x labwc >/dev/null 2>&1; then
        log "Anland display chain restarted for $RESOLUTION"
        exit 0
    fi
    sleep 0.1
done
fail "Anland did not negotiate $RESOLUTION after reconnect"
