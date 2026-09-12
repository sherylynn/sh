#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX_DIR=${NEWHOME_WLROOTS_PREFIX:-/opt/newhome-wayland/wlroots-anland}
BUILT_MARKER=${NEWHOME_WLROOTS_ANLAND_BUILT:-/opt/newhome-wayland/wlroots-anland.built}
READY_MARKER=${NEWHOME_WLROOTS_ANLAND_MARKER:-/opt/newhome-wayland/wlroots-anland.ready}
ANLAND_SOCKET=${ANLAND_SOCKET:-/tmp/anland/display_daemon.sock}
CONFIG_DIR=${NEWHOME_LABWC_CONFIG_DIR:-/root/.config/newhome-labwc}
LOG_DIR=${NEWHOME_WAYLAND_LOG_DIR:-/tmp/newhome-wayland}
SMOKE_LOG="$LOG_DIR/direct-smoke.log"
SMOKE_SECONDS=${NEWHOME_DIRECT_SMOKE_SECONDS:-10}

log() { printf '[wlroots-anland-smoke] %s\n' "$*"; }
fail() { printf '[wlroots-anland-smoke] ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "请在 chroot root 环境运行"
[ -f "$BUILT_MARKER" ] || fail "stage3 尚未构建；先运行 build_direct_backend.sh"
grep -q 'stage3-built' "$BUILT_MARKER" || fail "built marker 不是 stage3"
[ -d "$PREFIX_DIR/lib" ] || fail "缺少 direct wlroots lib 目录"
[ -S "$ANLAND_SOCKET" ] || fail "Anland daemon socket 不存在: $ANLAND_SOCKET"
command -v labwc >/dev/null 2>&1 || fail "缺少 labwc"

mkdir -p "$LOG_DIR" "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
chmod 0700 "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
rm -f "$READY_MARKER" "$SMOKE_LOG"

# Never disturb a live desktop silently. The normal switch-to-Wayland path can
# run this after stopping nested mode, or the user can invoke it from a shell.
if pgrep -x labwc >/dev/null 2>&1 || pgrep -x weston >/dev/null 2>&1; then
    fail "检测到现有 Labwc/Weston；请先停止当前 Wayland session 再 smoke test"
fi

export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=XFCE
export XDG_SESSION_TYPE=wayland
export GDK_BACKEND=wayland,x11
export QT_QPA_PLATFORM='wayland;xcb'
export WLR_BACKENDS=anland
export WLR_RENDERER=gles2
export ANLAND_SOCKET
export MESA_LOADER_DRIVER_OVERRIDE=kgsl
export TURNIP_KMD=kgsl
export GALLIUM_DRIVER=freedreno
export FD_FORCE_KGSL=1
export XWAYLAND_FORCE_KGSL_SURFACELESS=1
export LD_LIBRARY_PATH="$PREFIX_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

log "启动 direct Labwc stage3 smoke test (${SMOKE_SECONDS}s)"
log "测试期间 Android Anland Termux Activity 必须处于可见/已连接状态"

dbus-run-session -- labwc -C "$CONFIG_DIR" >"$SMOKE_LOG" 2>&1 &
PID=$!
cleanup() {
    kill "$PID" >/dev/null 2>&1 || true
    wait "$PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep "$SMOKE_SECONDS"
kill -0 "$PID" 2>/dev/null || {
    tail -n 120 "$SMOKE_LOG" >&2 || true
    fail "Labwc direct backend 在 smoke 窗口内退出"
}

require_log() {
    local pattern=$1 label=$2
    grep -Eqi "$pattern" "$SMOKE_LOG" || {
        tail -n 120 "$SMOKE_LOG" >&2 || true
        fail "未观察到 $label"
    }
}

reject_log() {
    local pattern=$1 label=$2
    if grep -Eqi "$pattern" "$SMOKE_LOG"; then
        tail -n 160 "$SMOKE_LOG" >&2 || true
        fail "检测到 $label"
    fi
}

require_log 'Created Anland backend|Starting Anland backend' 'Anland wlroots output 初始化'
require_log 'Anland Android consumer is ready' 'Android consumer ready'
require_log 'Anland presenter initialized' 'EGL/GLES DMA-BUF presenter 初始化'
reject_log 'non-DMA-BUF|DMA-BUF EGL import failed|target DMA-BUF is not GLES-renderable|GPU DMA-BUF presentation failed|Failed reading Anland buffer-ready' 'Stage3 presentation 错误'

log "自动检查通过：backend/consumer/EGL presenter 均保持运行，未发现 DMA-BUF 错误"
log "日志: $SMOKE_LOG"

if [ "${1:-}" != "--accept-visible" ]; then
    cat <<EOF

为了避免把“进程没崩但 Android 仍黑屏/方向错误”误标记为 ready，
本次不会创建：$READY_MARKER

请确认 Anland Android Activity 中已经能看到 Labwc/XFCE 画面且鼠标输入正常，
然后再次运行：
  $0 --accept-visible

第二次仍会重新跑完整 smoke test，通过后才写 ready。
EOF
    exit 0
fi

printf 'stage3-visible wlroots-anland GPU-blit validated %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$READY_MARKER"
log "真机可见性已由调用者确认，已启用 direct auto mode: $READY_MARKER"
