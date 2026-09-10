#!/bin/bash
set -e

SCALING_SCRIPT=/root/sh/win-git/xfce4-scaling.sh
PENDING=/tmp/xfce-remote-profile.pending
WORKER_LOCK=/tmp/xfce-remote-profile.worker.lock
SUPPRESS_FILE=/tmp/xfce-remote-resize.suppress-until
LOG_FILE=/tmp/x11vnc-remote-resize.log

resolution=${1:-}
dpi=${2:-0}

[[ "$resolution" =~ ^[0-9]+x[0-9]+$ ]] || exit 2
width=${resolution%x*}
height=${resolution#*x}
(( width >= 320 && width <= 8192 && height >= 240 && height <= 8192 )) || exit 2
[[ "$dpi" =~ ^[0-9]+$ ]] || exit 2

scale=0
if (( dpi >= 48 && dpi <= 768 )); then
  if (( dpi >= 240 )); then
    scale=3
  elif (( dpi >= 144 )); then
    scale=2
  else
    scale=1
  fi
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

"$SCALING_SCRIPT" --remote-resize "$final_resolution"
if (( final_scale > 0 )); then
  "$SCALING_SCRIPT" --apply-scale "$final_scale"
fi
