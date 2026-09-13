#!/bin/bash
# Android Activity 从后台恢复时，Anland 5.13.3 不一定会把新 Surface 的
# DMA-BUF 再交给已连接的 wlroots producer。本监视器只在该异常出现时
# 重连 Labwc；Activity 留在后台时不做任何操作，让 noVNC 继续工作。
set -u

DAEMON_LOG=/tmp/anland/newhome-anland.log
WATCHDOG_LOG=/tmp/newhome-anland-resume-watchdog.log
LOCK_FILE=/tmp/newhome-anland-resume-watchdog.lock
SESSION_SCRIPT=/root/sh/termux/chroot/wayland/start_labwc_anland.sh
RESIZE_SCRIPT=/root/sh/termux/chroot/wayland/anland_remote_resize.sh

log() {
    printf 'time=%s %s\n' "$(date +%s)" "$*" >> "$WATCHDOG_LOG"
}

last_line() {
    local pattern=$1
    grep -nF "$pattern" "$DAEMON_LOG" 2>/dev/null | tail -n 1 |
        cut -d: -f1
}

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

DAEMON_PID=$(pgrep -xo anland 2>/dev/null || true)
[ -n "$DAEMON_PID" ] || exit 0
handled_disconnect=0
log "watching daemon pid=$DAEMON_PID"

while kill -0 "$DAEMON_PID" 2>/dev/null; do
    disconnected=$(last_line 'consumer disconnected')
    connected=$(last_line 'consumer connected,')
    delivered=$(last_line 'fds delivered to producer')
    disconnected=${disconnected:-0}
    connected=${connected:-0}
    delivered=${delivered:-0}

    if (( disconnected > handled_disconnect && connected > disconnected )); then
        # 正常 Surface 重建会在很短时间内自行交付，先给 daemon 留出窗口。
        sleep 1
        delivered=$(last_line 'fds delivered to producer')
        delivered=${delivered:-0}
        handled_disconnect=$disconnected
        if (( delivered < connected )); then
            resolution=$(sed -n 's/.*screen info \([0-9]*x[0-9]*\) .*/\1/p' \
                "$DAEMON_LOG" | tail -n 1)
            log "resume missing fd delivery after line=$connected; rebind producer"
            pkill -TERM -x labwc >/dev/null 2>&1 || true
            for _ in {1..30}; do
                pgrep -x labwc >/dev/null 2>&1 || break
                sleep 0.1
            done
            pkill -KILL -x labwc >/dev/null 2>&1 || true
            nohup env NEWHOME_WAYLAND_MODE=direct /bin/bash "$SESSION_SCRIPT" \
                >/tmp/newhome-wayland-session-supervisor.log 2>&1 </dev/null 9>&- &

            recovered=0
            for _ in {1..80}; do
                new_delivery=$(last_line 'fds delivered to producer')
                new_delivery=${new_delivery:-0}
                if pgrep -x labwc >/dev/null 2>&1 && (( new_delivery > connected )); then
                    recovered=1
                    break
                fi
                sleep 0.1
            done
            if [ "$recovered" -eq 1 ]; then
                /etc/init.d/noVNC stop >/dev/null 2>&1 || true
                /etc/init.d/noVNC start >/dev/null 2>&1 || true
                log "producer rebound; noVNC binding restarted"
            elif [[ "$resolution" =~ ^[0-9]+x[0-9]+$ ]]; then
                log "minimal rebind failed; forcing display-chain recovery $resolution"
                ANLAND_FORCE_RESTART=1 /bin/bash "$RESIZE_SCRIPT" "$resolution" || \
                    log "ERROR: forced display-chain recovery failed"
            else
                log "ERROR: minimal rebind failed and resolution is unknown"
            fi
        fi
    fi
    sleep 0.5
done
log "daemon pid changed or stopped; watchdog exiting"
