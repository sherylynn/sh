#!/bin/bash
# 合并 noVNC 在窗口拖动、侧栏开合和重连时密集发送的 SetDesktopSize。
# 每个请求只更新 pending；唯一 leader 等尺寸稳定后应用最后一个目标。
set -u

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RESOLUTION=${1:-}
PENDING=/tmp/anland-remote-resize.pending
LEADER_DIR=/tmp/anland-remote-resize-leader
RESIZE_SCRIPT=/root/sh/termux/chroot/wayland/anland_remote_resize.sh
LOG_FILE=/tmp/anland-remote-resize-queue.log
SUPPRESS_FILE=/tmp/anland-remote-resize-suppress-until
STALE_VIEWPORT_FILE=/tmp/anland-remote-resize-stale-viewport

[[ "$RESOLUTION" =~ ^[0-9]+x[0-9]+$ ]] || exit 1
# 托盘手动预设重建显示链后，noVNC 会在自动重连时重发浏览器视口。
# 短暂尊重手动设置，避免它刚应用就被重连请求覆盖。
now=$(date +%s)
suppress_until=$(head -n 1 "$SUPPRESS_FILE" 2>/dev/null || echo 0)
if [[ "$suppress_until" =~ ^[0-9]+$ ]] && (( now < suppress_until )); then
    printf 'time=%s ignored=%s reason=manual-profile-cooldown\n' "$now" "$RESOLUTION" \
        >> "$LOG_FILE"
    exit 0
fi
# 托盘预设后 noVNC 可能长期周期性重发调整前的视口，而不只在首次重连时
# 发送一次。只忽略这个明确记录的旧尺寸；浏览器出现任意其他新尺寸时，
# 视为用户真的调整了窗口，立即恢复远程自适应。
stale_viewport=$(head -n 1 "$STALE_VIEWPORT_FILE" 2>/dev/null || true)
if [ -n "$stale_viewport" ] && [ "$RESOLUTION" = "$stale_viewport" ]; then
    printf 'time=%s ignored=%s reason=stale-browser-viewport\n' "$now" "$RESOLUTION" \
        >> "$LOG_FILE"
    exit 0
fi
# noVNC 的渲染遥测也复用 SetDesktopSize，并携带当前 framebuffer 尺寸。
# neatvnc 的公开 layout API 读不到私有 flags，因此在进入 pending 队列前，
# 直接忽略与 Anland 当前活动输出相同的尺寸，避免覆盖真正的新目标。
ACTIVE_RESOLUTION=$(sed -n 's/.*screen info \([0-9][0-9]*x[0-9][0-9]*\) .*/\1/p' \
    /tmp/anland/newhome-anland.log 2>/dev/null | tail -n 1)
if [ "$RESOLUTION" = "$ACTIVE_RESOLUTION" ]; then
    printf 'time=%s ignored-current=%s\n' "$(date +%s)" "$RESOLUTION" >> "$LOG_FILE"
    exit 0
fi
[ -z "$stale_viewport" ] || rm -f "$STALE_VIEWPORT_FILE"
temporary="${PENDING}.$$"
printf '%s\n' "$RESOLUTION" > "$temporary"
mv -f "$temporary" "$PENDING"

# mkdir 锁没有可继承的文件描述符。后来者只更新 pending 后立即退出，
# 不会像 flock worker 那样在 display lock 后面堆积一长串过期尺寸。
mkdir "$LEADER_DIR" 2>/dev/null || exit 0
trap 'rmdir "$LEADER_DIR" 2>/dev/null || true' EXIT INT TERM

while true; do
    # 等浏览器拖动稳定，再原子取走当前最后目标。
    sleep 1
    [ -s "$PENDING" ] || break
    target=$(head -n 1 "$PENDING")
    rm -f "$PENDING"
    [[ "$target" =~ ^[0-9]+x[0-9]+$ ]] || continue

    now=$(date +%s)
    suppress_until=$(head -n 1 "$SUPPRESS_FILE" 2>/dev/null || echo 0)
    if [[ "$suppress_until" =~ ^[0-9]+$ ]] && (( now < suppress_until )); then
        printf 'time=%s ignored=%s reason=manual-profile-cooldown\n' "$now" "$target" \
            >> "$LOG_FILE"
        continue
    fi

    stale_viewport=$(head -n 1 "$STALE_VIEWPORT_FILE" 2>/dev/null || true)
    if [ -n "$stale_viewport" ] && [ "$target" = "$stale_viewport" ]; then
        printf 'time=%s ignored=%s reason=stale-browser-viewport\n' "$now" "$target" \
            >> "$LOG_FILE"
        continue
    fi

    ACTIVE_RESOLUTION=$(sed -n 's/.*screen info \([0-9][0-9]*x[0-9][0-9]*\) .*/\1/p' \
        /tmp/anland/newhome-anland.log 2>/dev/null | tail -n 1)
    [ "$target" = "$ACTIVE_RESOLUTION" ] && continue
    [ -z "$stale_viewport" ] || rm -f "$STALE_VIEWPORT_FILE"

    printf 'time=%s applying=%s requested=%s\n' "$(date +%s)" "$target" "$RESOLUTION" \
        >> "$LOG_FILE"
    # leader 是唯一调用者；display lock 仅用于与托盘手动请求互斥。
    /bin/bash "$RESIZE_SCRIPT" "$target" --queued >> "$LOG_FILE" 2>&1
done
