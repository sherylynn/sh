#!/bin/bash
set -euo pipefail

CONFIG_DIR=${NEWHOME_LABWC_CONFIG_DIR:-/root/.config/newhome-labwc}
ANLAND_SOCKET=${ANLAND_SOCKET:-/tmp/anland/display_daemon.sock}
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
HOST_SOCKET=${NEWHOME_WESTON_SOCKET:-wayland-anland-host}
WAYLAND_MODE=${NEWHOME_WAYLAND_MODE:-auto}
DIRECT_MARKER=${NEWHOME_WLROOTS_ANLAND_MARKER:-/opt/newhome-wayland/wlroots-anland.ready}
DIRECT_LIBDIR=${NEWHOME_WLROOTS_ANLAND_LIBDIR:-/opt/newhome-wayland/wlroots-anland/lib}
LOG_DIR=${NEWHOME_WAYLAND_LOG_DIR:-/tmp/newhome-wayland}

log() { printf '[labwc-anland] %s\n' "$*"; }
fail() { printf '[labwc-anland] ERROR: %s\n' "$*" >&2; exit 1; }

wait_socket() {
    local socket=$1 attempts=${2:-100}
    while [ "$attempts" -gt 0 ]; do
        [ -S "$socket" ] && return 0
        sleep 0.1
        attempts=$((attempts - 1))
    done
    return 1
}

prepare_common() {
    [ -S "$ANLAND_SOCKET" ] || fail "Anland daemon socket 不存在: $ANLAND_SOCKET"
    command -v labwc >/dev/null 2>&1 || fail "缺少 labwc，请先运行 install_anland_wayland.sh"

    install -d -m 0700 "$XDG_RUNTIME_DIR"
    install -d -m 0700 "$CONFIG_DIR"
    install -d -m 0755 "$LOG_DIR"
    install -d -m 1777 /tmp/.X11-unix
    chmod 0711 "${ANLAND_SOCKET%/*}" 2>/dev/null || true
    chmod 0666 "$ANLAND_SOCKET" 2>/dev/null || true

    unset DISPLAY
    export XDG_RUNTIME_DIR
    export XDG_CURRENT_DESKTOP=XFCE
    export XDG_SESSION_DESKTOP=XFCE
    export XDG_SESSION_TYPE=wayland
    export GDK_BACKEND=wayland,x11
    export QT_QPA_PLATFORM='wayland;xcb'

    # SM8750/Adreno: use the same KGSL Freedreno/Turnip route recommended by
    # Anland-Termux. These variables are harmless on the direct backend and are
    # also needed by XWayland clients under Labwc.
    export MESA_LOADER_DRIVER_OVERRIDE=kgsl
    export TURNIP_KMD=kgsl
    export GALLIUM_DRIVER=freedreno
    export FD_FORCE_KGSL=1
    export XWAYLAND_FORCE_KGSL_SURFACELESS=1
    export ANLAND_DRM_DEVICE=${ANLAND_DRM_DEVICE:-/dev/dri/renderD128}
    export ANLAND_SOCKET
}

cleanup() {
    pkill -x labwc >/dev/null 2>&1 || true
    pkill -x weston >/dev/null 2>&1 || true
    rm -f "$XDG_RUNTIME_DIR/$HOST_SOCKET" "$XDG_RUNTIME_DIR/$HOST_SOCKET.lock" 2>/dev/null || true
}

start_direct() {
    [ -e "$DIRECT_MARKER" ] || fail "direct 模式要求 $DIRECT_MARKER"
    [ -d "$DIRECT_LIBDIR" ] || fail "direct wlroots 库目录不存在: $DIRECT_LIBDIR"

    log "启动 direct 模式: Labwc -> wlroots-anland -> Anland"
    unset WAYLAND_DISPLAY
    export WLR_BACKENDS=anland
    export LD_LIBRARY_PATH="$DIRECT_LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    # Our wlroots backend contract deliberately reuses ANLAND_SOCKET rather than
    # introducing a second display-daemon environment variable.
    exec dbus-run-session -- labwc -C "$CONFIG_DIR"
}

start_nested() {
    command -v weston >/dev/null 2>&1 || fail "缺少 Anland patched Weston bootstrap"
    log "启动 bootstrap 模式: Labwc -> wlroots Wayland backend -> Weston-Anland -> Anland"

    rm -f "$XDG_RUNTIME_DIR/$HOST_SOCKET" "$XDG_RUNTIME_DIR/$HOST_SOCKET.lock" 2>/dev/null || true

    # kiosk-shell makes the one nested Labwc output occupy the Android display;
    # Weston is only a transport/bootstrap producer and is not the user desktop.
    weston \
        --backend=anland \
        --renderer=gl \
        --disp-sock="$ANLAND_SOCKET" \
        --socket="$HOST_SOCKET" \
        --shell=kiosk-shell.so \
        --idle-time=0 \
        >"$LOG_DIR/weston.log" 2>&1 &
    WESTON_PID=$!

    if ! wait_socket "$XDG_RUNTIME_DIR/$HOST_SOCKET" 120; then
        kill "$WESTON_PID" >/dev/null 2>&1 || true
        fail "Weston-Anland 未创建 $HOST_SOCKET；查看 $LOG_DIR/weston.log"
    fi

    export WAYLAND_DISPLAY="$HOST_SOCKET"
    export WLR_BACKENDS=wayland
    export WLR_WL_OUTPUTS=1

    # Labwc's autostart runs after it creates its own Wayland socket, so
    # xfce4-panel/Thunar/xfsettingsd automatically connect to Labwc rather than
    # the outer Weston transport compositor.
    dbus-run-session -- labwc -C "$CONFIG_DIR" >"$LOG_DIR/labwc.log" 2>&1 || STATUS=$?
    STATUS=${STATUS:-0}
    kill "$WESTON_PID" >/dev/null 2>&1 || true
    wait "$WESTON_PID" 2>/dev/null || true
    return "$STATUS"
}

main() {
    prepare_common
    trap cleanup EXIT INT TERM
    cleanup

    case "$WAYLAND_MODE" in
        direct)
            trap - EXIT
            start_direct
            ;;
        nested)
            start_nested
            ;;
        auto)
            if [ -e "$DIRECT_MARKER" ] && [ -d "$DIRECT_LIBDIR" ]; then
                trap - EXIT
                start_direct
            else
                log "wlroots-anland 尚未安装，使用 Weston bootstrap；桌面仍由 Labwc/XFCE 提供"
                start_nested
            fi
            ;;
        *)
            fail "未知 NEWHOME_WAYLAND_MODE=$WAYLAND_MODE (支持 auto/direct/nested)"
            ;;
    esac
}

main "$@"
