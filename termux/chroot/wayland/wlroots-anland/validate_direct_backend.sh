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
[ -f "$BUILT_MARKER" ] || fail "direct backend 尚未构建；先运行 build_direct_backend.sh"
[ -d "$PREFIX_DIR/lib" ] || fail "缺少 direct wlroots lib 目录"
[ -S "$ANLAND_SOCKET" ] || fail "Anland daemon socket 不存在: $ANLAND_SOCKET"
command -v labwc >/dev/null 2>&1 || fail "缺少 labwc"

BUILD_DESC=$(cat "$BUILT_MARKER")
case "$BUILD_DESC" in
    stage4-zero-copy-built*) BUILD_STAGE=stage4 ;;
    stage3-built*) BUILD_STAGE=stage3 ;;
    *) fail "无法识别 built marker: $BUILD_DESC" ;;
esac

mkdir -p "$LOG_DIR" "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
chmod 0700 "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
rm -f "$READY_MARKER" "$SMOKE_LOG"

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
export ANLAND_DRM_DEVICE=${ANLAND_DRM_DEVICE:-/dev/dri/renderD128}
export MESA_LOADER_DRIVER_OVERRIDE=kgsl
export TURNIP_KMD=kgsl
export GALLIUM_DRIVER=freedreno
export FD_FORCE_KGSL=1
export XWAYLAND_FORCE_KGSL_SURFACELESS=1
export LD_LIBRARY_PATH="$PREFIX_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

[ -r "$ANLAND_DRM_DEVICE" ] && [ -w "$ANLAND_DRM_DEVICE" ] || \
    fail "render node 不可读写: $ANLAND_DRM_DEVICE"

log "启动 direct Labwc ${BUILD_STAGE} smoke test (${SMOKE_SECONDS}s)"
log "测试期间 Android Anland Termux Activity 必须处于可见/已连接状态"

setsid dbus-run-session -- labwc -d -C "$CONFIG_DIR" >"$SMOKE_LOG" 2>&1 &
PID=$!
cleanup() {
    kill -TERM -- "-$PID" >/dev/null 2>&1 || true
    sleep 0.2
    kill -KILL -- "-$PID" >/dev/null 2>&1 || true
    wait "$PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep "$SMOKE_SECONDS"
kill -0 "$PID" 2>/dev/null || {
    tail -n 200 "$SMOKE_LOG" >&2 || true
    fail "Labwc direct backend 在 smoke 窗口内退出"
}

require_log() {
    local pattern=$1 label=$2
    grep -Eqi "$pattern" "$SMOKE_LOG" || {
        tail -n 200 "$SMOKE_LOG" >&2 || true
        fail "未观察到 $label"
    }
}

reject_log() {
    local pattern=$1 label=$2
    if grep -Eqi "$pattern" "$SMOKE_LOG"; then
        tail -n 240 "$SMOKE_LOG" >&2 || true
        fail "检测到 $label"
    fi
}

require_log 'Anland render node:' 'wlroots render node'
require_log 'Created Anland backend|Starting Anland backend' 'Anland wlroots backend 初始化'
require_log 'Anland Android consumer is ready' 'Android consumer ready'

if [ "$BUILD_STAGE" = stage4 ]; then
    require_log 'Anland zero-copy pool imported:' 'Android consumer DMA-BUF pool 导入'
    require_log 'Anland first zero-copy frame presented:' '至少一帧真正 zero-copy presentation'
    require_log 'Anland zero-copy continuous frame loop established' '至少两帧连续 zero-copy presentation'
    reject_log 'anland presenter initialized|GPU-only EGL DMA-BUF blit|glFinish' \
        'Stage3 presenter 路径意外进入 Stage4 runtime'
    reject_log 'ZERO-COPY DMA-BUF presentation failed|zero-copy trigger_refresh failed|buffer rotation mismatch|consumer selected invalid buffer|consumer pool import failed|Unable to open Anland render node' \
        'Stage4 zero-copy presentation 错误'
    log "自动检查通过：Labwc/wlroots 已直接渲染 consumer-selected Anland DMA-BUF，并完成 trigger_refresh"
else
    require_log 'Anland presenter initialized' 'Stage3 EGL/GLES DMA-BUF presenter 初始化'
    require_log 'Anland first GPU DMA-BUF frame presented successfully' '至少一帧 Stage3 GPU DMA-BUF presentation'
    reject_log 'non-DMA-BUF|DMA-BUF EGL import failed|target DMA-BUF is not GLES-renderable|GPU DMA-BUF presentation failed|Failed reading Anland buffer-ready|Unable to open Anland render node' \
        'Stage3 presentation 错误'
    log "Stage3 fallback 自动检查通过：GPU blit -> Anland trigger_refresh"
fi

log "日志: $SMOKE_LOG"

if [ "${1:-}" != "--accept-visible" ]; then
    cat <<EOF

自动层已经通过，但仍不会直接写 ready。
请在 Android Anland Activity 中确认：
  1. Labwc/XFCE 画面可见；
  2. 方向和颜色正确；
  3. 鼠标/键盘输入正常；
  4. 没有明显闪屏/多缓冲旧帧交替。

确认后再次运行：
  $0 --accept-visible

第二次仍会重新跑完整 smoke，通过后才写：
  $READY_MARKER
EOF
    exit 0
fi

if [ "$BUILD_STAGE" = stage4 ]; then
    printf 'stage4-zero-copy-visible wlroots-anland validated %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$READY_MARKER"
else
    printf 'stage3-visible wlroots-anland GPU-blit validated %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$READY_MARKER"
fi
log "真机可见性已由调用者确认，已启用 direct auto mode: $READY_MARKER"
