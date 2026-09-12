#!/bin/bash
set -euo pipefail

PREFIX_DIR=${NEWHOME_WLROOTS_PREFIX:-/opt/newhome-wayland/wlroots-anland}
BUILT_MARKER=${NEWHOME_WLROOTS_ANLAND_BUILT:-/opt/newhome-wayland/wlroots-anland.built}
READY_MARKER=${NEWHOME_WLROOTS_ANLAND_MARKER:-/opt/newhome-wayland/wlroots-anland.ready}
ANLAND_SOCKET=${ANLAND_SOCKET:-/tmp/anland/display_daemon.sock}
SMOKE_BIN=${NEWHOME_WLROOTS_ANLAND_SMOKE:-$PREFIX_DIR/bin/wlr-anland-smoke}

log() { printf '[wlroots-anland-activate] %s\n' "$*"; }
fail() { printf '[wlroots-anland-activate] ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "请在 chroot root 环境运行"
[ -f "$BUILT_MARKER" ] || fail "direct backend 尚未 build: $BUILT_MARKER"
[ -S "$ANLAND_SOCKET" ] || fail "Anland socket 不存在: $ANLAND_SOCKET；先启动 Anland Termux/daemon"
[ -x "$SMOKE_BIN" ] || fail "backend 尚未提供 runtime smoke binary: $SMOKE_BIN"

rm -f "$READY_MARKER"

log "运行 direct backend smoke test（输出/输入/DMA-BUF）"
if ! timeout 12s env \
    ANLAND_SOCKET="$ANLAND_SOCKET" \
    LD_LIBRARY_PATH="$PREFIX_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$SMOKE_BIN" --require-consumer --frames 3; then
    fail "smoke test 失败；保持 nested Weston fallback，不启用 direct mode"
fi

printf '%s\n' "$(cat "$BUILT_MARKER") runtime-smoke=passed $(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    > "$READY_MARKER"
log "direct backend 已通过真机 smoke test并启用: $READY_MARKER"
log "下一次 NEWHOME_WAYLAND_MODE=auto 会直接使用 Labwc -> wlroots-anland -> Anland。"
