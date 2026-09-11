#!/bin/bash
set -e

SCALING_SCRIPT=/root/sh/win-git/xfce4-scaling.sh
PENDING=/tmp/xfce-remote-profile.pending
WORKER_LOCK=/tmp/xfce-remote-profile.worker.lock
SUPPRESS_FILE=/tmp/xfce-remote-resize.suppress-until
LOG_FILE=/tmp/x11vnc-remote-resize.log
TRAY_EVENT=/tmp/xfce-display-remote-event

publish_tray_event() {
  local state=$1 message=$2 temporary="${TRAY_EVENT}.$$"
  printf '%s\t%s\t%s\n' "$(date +%s%N)" "$state" "$message" > "$temporary"
  mv -f "$temporary" "$TRAY_EVENT"
}

resolution=${1:-}
dpi=${2:-0}

[[ "$resolution" =~ ^[0-9]+x[0-9]+$ ]] || exit 2
width=${resolution%x*}
height=${resolution#*x}
(( width >= 320 && width <= 8192 && height >= 240 && height <= 8192 )) || exit 2
[[ "$dpi" =~ ^[0-9]+$ ]] || exit 2

scale=0
if (( dpi >= 48 && dpi <= 768 )); then
  scale=$(awk -v dpi="$dpi" 'BEGIN { printf "%.4g", dpi / 96 }')
fi

now=$(date +%s)
suppress_until=0
[ -f "$SUPPRESS_FILE" ] && suppress_until=$(head -n 1 "$SUPPRESS_FILE" 2>/dev/null || echo 0)
if [[ "$suppress_until" =~ ^[0-9]+$ ]] && (( now < suppress_until )); then
  printf 'time=%s ignored=%s dpi=%s reason=manual-profile-cooldown\n' \
    "$now" "$resolution" "$dpi" >> "$LOG_FILE"
  exit 0
fi

# Resolution, integer UI scale, and source DPI form one atomic pending profile.
printf '%s %s %s\n' "$resolution" "$scale" "$dpi" > "${PENDING}.$$"
mv -f "${PENDING}.$$" "$PENDING"

exec 8>"$WORKER_LOCK"
flock -n 8 || exit 0

while true; do
  next=$(head -n 1 "$PENDING" 2>/dev/null || true)
  sleep 1
  [ "$next" = "$(head -n 1 "$PENDING" 2>/dev/null || true)" ] && break
done

read -r final_resolution final_scale final_dpi < "$PENDING"
printf 'time=%s apply-profile=%s dpi=%s scale=%s\n' \
  "$(date +%s)" "$final_resolution" "$final_dpi" "$final_scale" >> "$LOG_FILE"
publish_tray_event received \
  "浏览器请求：${final_resolution}，DPI ${final_dpi}，界面缩放 ${final_scale}x"

# Release the lock before launching desktop programs. Otherwise fcitx5 and other
# long-lived children inherit fd 8 and permanently block every later client.
flock -u 8
exec 8>&-

if ! "$SCALING_SCRIPT" --remote-resize "$final_resolution"; then
  publish_tray_event failed "远程分辨率 ${final_resolution} 应用失败"
  exit 1
fi
if awk -v scale="$final_scale" 'BEGIN { exit !(scale >= 0.5 && scale <= 4) }'; then
  if ! "$SCALING_SCRIPT" --apply-remote-scale "$final_scale"; then
    publish_tray_event failed "分辨率已设为 ${final_resolution}，缩放 ${final_scale}x 应用失败"
    exit 1
  fi
fi
publish_tray_event applied \
  "已应用：${final_resolution}，DPI ${final_dpi}，界面缩放 ${final_scale}x"
