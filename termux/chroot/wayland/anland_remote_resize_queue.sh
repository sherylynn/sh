#!/bin/bash
# 合并 noVNC 在窗口拖动、侧栏开合和重连时密集发送的 SetDesktopSize。
# 每个请求先更新 pending；排队 worker 获得锁后只执行当时的最后一个尺寸。
set -u

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RESOLUTION=${1:-}
PENDING=/tmp/anland-remote-resize.pending
QUEUE_LOCK=/tmp/anland-remote-resize-queue.lock
RESIZE_SCRIPT=/root/sh/termux/chroot/wayland/anland_remote_resize.sh
LOG_FILE=/tmp/anland-remote-resize-queue.log

[[ "$RESOLUTION" =~ ^[0-9]+x[0-9]+$ ]] || exit 1
# noVNC 的渲染遥测也复用 SetDesktopSize，并携带当前 framebuffer 尺寸。
# neatvnc 的公开 layout API 读不到私有 flags，因此在进入 pending 队列前，
# 直接忽略与 Anland 当前活动输出相同的尺寸，避免覆盖真正的新目标。
ACTIVE_RESOLUTION=$(sed -n 's/.*screen info \([0-9][0-9]*x[0-9][0-9]*\) .*/\1/p' \
    /tmp/anland/newhome-anland.log 2>/dev/null | tail -n 1)
if [ "$RESOLUTION" = "$ACTIVE_RESOLUTION" ]; then
    printf 'time=%s ignored-current=%s\n' "$(date +%s)" "$RESOLUTION" >> "$LOG_FILE"
    exit 0
fi
temporary="${PENDING}.$$"
printf '%s\n' "$RESOLUTION" > "$temporary"
mv -f "$temporary" "$PENDING"

exec 8>"$QUEUE_LOCK"
flock 8
# 等浏览器尺寸稳定后再读取，期间的新请求会覆盖 pending。
sleep 1
[ -s "$PENDING" ] || exit 0
target=$(head -n 1 "$PENDING")
rm -f "$PENDING"
[[ "$target" =~ ^[0-9]+x[0-9]+$ ]] || exit 1
printf 'time=%s applying=%s requested=%s\n' "$(date +%s)" "$target" "$RESOLUTION" \
    >> "$LOG_FILE"
# 显示链重启会派生 wayvnc/websockify 等长期进程。调用重启前必须关闭
# 队列锁文件描述符，否则守护进程继承锁后，后续远程尺寸会永久排队。
# 真正的重启仍由 anland_remote_resize.sh 的 display lock 串行化。
flock -u 8
exec 8>&-
# queue 已经串行化；这里使用阻塞模式，不能在手动托盘操作占锁时丢请求。
/bin/bash "$RESIZE_SCRIPT" "$target" --queued >> "$LOG_FILE" 2>&1
