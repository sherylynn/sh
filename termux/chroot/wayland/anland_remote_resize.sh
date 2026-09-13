#!/bin/bash
# Apply a noVNC framebuffer size to Anland and rebuild only the display chain.
# The Debian mount/container is deliberately left intact.
set -euo pipefail

# wayvnc 的 LD_PRELOAD worker 使用精简环境启动，不能依赖调用者 PATH。
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RESOLUTION=${1:-}
REQUEST_KIND=${2:-manual}
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SESSION_SCRIPT="$SCRIPT_DIR/start_labwc_anland.sh"
ANLAND_PACKAGE=com.anland.termux
ANLAND_ACTIVITY=com.anland.termux/.MainActivity
ANLAND_SOCKET=/data/data/com.termux/files/usr/tmp/anland/display_daemon.sock
LOG_FILE=/tmp/newhome-anland-resize.log
LOCK_FILE=/tmp/anland-display-resize.lock

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
if [ "$REQUEST_KIND" = "--remote" ]; then
    flock -n 9 || exit 0
else
    # 托盘手动操作必须等待并真正完成，不能因 noVNC worker 占锁而假成功。
    flock 9
fi

# A host Termux process gives this chroot a stable view of Android's /system and
# /data. Do not depend on the Anland process itself: it is replaced below.
TERMUX_PID=$(ps -eo pid,args | awk \
    '/\/data\/data\/com\.termux\/files\/usr\/bin\/(bash|zsh)/ && !/awk/ {print $1; exit}')
if [ -z "$TERMUX_PID" ]; then
    TERMUX_PID=$(pgrep -xo com.termux 2>/dev/null || true)
fi
[ -n "$TERMUX_PID" ] || fail "cannot locate a host Termux process"
HOST_ROOT=/proc/$TERMUX_PID/root
[ -x "$HOST_ROOT/system/bin/am" ] || fail "Android activity manager is unavailable"
TERMUX_UID=$(stat -c %u "$HOST_ROOT/data/data/com.termux")
[[ "$TERMUX_UID" =~ ^[0-9]+$ ]] || fail "cannot resolve Termux UID"

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
if [ "${ANLAND_FORCE_RESTART:-0}" != 1 ] && \
        [ "$(read_int_pref custom_width)" = "$WIDTH" ] && \
        [ "$(read_int_pref custom_height)" = "$HEIGHT" ] && \
        grep -q "screen info ${WIDTH}x${HEIGHT} " /tmp/anland/newhome-anland.log 2>/dev/null && \
        (pgrep -x weston >/dev/null 2>&1 || pgrep -x labwc >/dev/null 2>&1); then
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
# 旧版本可能留下 root daemon；必须在降权前清理，否则 Termux UID 无法杀死它。
pkill -TERM -x anland >/dev/null 2>&1 || true
sleep 0.2
pkill -KILL -x anland >/dev/null 2>&1 || true
TERMUX_DAEMON_COMMAND='rm -f "$PREFIX/tmp/anland/display_daemon.sock"; mkdir -p "$PREFIX/tmp/anland"; nohup anland --socket "$PREFIX/tmp/anland/display_daemon.sock" >"$PREFIX/tmp/anland/newhome-anland.log" 2>&1 </dev/null 9>&- &'
# 不使用 login shell；Termux profile 可能按历史配置再次提权。
chroot "$HOST_ROOT" "$PREFIX/bin/setpriv" \
    --reuid "$TERMUX_UID" --regid "$TERMUX_UID" --clear-groups \
    "$PREFIX/bin/env" -i \
    HOME=/data/data/com.termux/files/home PREFIX="$PREFIX" TMPDIR="$PREFIX/tmp" \
    PATH="$PREFIX/bin:/system/bin:/system/xbin" SHELL="$PREFIX/bin/bash" \
    "$PREFIX/bin/bash" -c "$TERMUX_DAEMON_COMMAND"

for _ in {1..100}; do
    [ -S /tmp/anland/display_daemon.sock ] && break
    sleep 0.1
done
[ -S /tmp/anland/display_daemon.sock ] || fail "Anland daemon socket did not return"

nohup env NEWHOME_WAYLAND_MODE=${NEWHOME_WAYLAND_MODE:-auto} \
    /bin/bash "$SESSION_SCRIPT" >/tmp/newhome-wayland-session-supervisor.log 2>&1 </dev/null 9>&- &
for _ in {1..120}; do
    if pgrep -x weston >/dev/null 2>&1 || pgrep -x labwc >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done

android am start --user 0 -n "$ANLAND_ACTIVITY" >/dev/null
for _ in {1..150}; do
    if grep -q "screen info ${WIDTH}x${HEIGHT} " /tmp/anland/newhome-anland.log 2>/dev/null && \
            (pgrep -x weston >/dev/null 2>&1 || pgrep -x labwc >/dev/null 2>&1); then
        # wayvnc 绑定旧 compositor，Labwc 重建后它会自动退出。
        # 等新 Wayland socket 就绪后重启代理，让 noVNC 原连接自动回连。
        for _wayland_wait in {1..100}; do
            [ -S /run/user/0/wayland-0 ] && break
            sleep 0.1
        done
        if [ -x /etc/init.d/noVNC ]; then
            # 不能让长期运行的 wayvnc/websockify 继承 display lock，
            # 否则托盘和下一次浏览器调整都会永久阻塞。
            /etc/init.d/noVNC stop 9>&- >/dev/null 2>&1 || true
            /etc/init.d/noVNC start 9>&- >/dev/null 2>&1 || \
                fail "Anland resized, but noVNC/wayvnc restart failed"
        fi
        log "Anland display chain restarted for $RESOLUTION"
        exit 0
    fi
    sleep 0.1
done
fail "Anland did not negotiate $RESOLUTION after reconnect"
