#!/data/data/com.termux/files/usr/bin/bash
# Independent Wayland profile. It intentionally does not start/stop Termux:X11.
# X11 remains the stable default in termux_all_in_one.sh.
set -euo pipefail

PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
HOME=${HOME:-/data/data/com.termux/files/home}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYLAND_DIR="$SCRIPT_DIR/wayland"
SESSION_SCRIPT="/root/sh/termux/chroot/wayland/start_labwc_anland.sh"
SESSION_LOG="/tmp/newhome-wayland-session-supervisor.log"

# shellcheck source=wayland/anland_versions.sh
. "$WAYLAND_DIR/anland_versions.sh"
# shellcheck source=cli.sh
set +e
. "$SCRIPT_DIR/cli.sh"
set -e

log() { printf '[wayland] %s\n' "$*"; }
fail() { printf '[wayland] ERROR: %s\n' "$*" >&2; exit 1; }

wait_socket() {
    local socket=$1 attempts=${2:-100}
    while [ "$attempts" -gt 0 ]; do
        [ -S "$socket" ] && return 0
        sleep 0.1
        attempts=$((attempts - 1))
    done
    return 1
}

check_requirements() {
    command -v anland >/dev/null 2>&1 || fail "未安装 Anland daemon；先运行 bash $WAYLAND_DIR/install_anland_wayland.sh"
    command -v am >/dev/null 2>&1 || fail "缺少 Android am 命令"
    [ -x "$PREFIX/bin/bash" ] || fail "Termux bash 不可用"
}

stop_anland() {
    pkill -TERM -x anland-compatible >/dev/null 2>&1 || true
    pkill -TERM -x anland >/dev/null 2>&1 || true
    sleep 0.3
    pkill -KILL -x anland-compatible >/dev/null 2>&1 || true
    pkill -KILL -x anland >/dev/null 2>&1 || true
    rm -f "$ANLAND_SOCKET_TERMUX" 2>/dev/null || true
}

start_anland() {
    log "启动 Anland $ANLAND_VERSION daemon"
    mkdir -p "${ANLAND_SOCKET_TERMUX%/*}"
    stop_anland
    anland --socket "$ANLAND_SOCKET_TERMUX" \
        >"${ANLAND_SOCKET_TERMUX%/*}/newhome-anland.log" 2>&1 &
    local pid=$!
    if ! wait_socket "$ANLAND_SOCKET_TERMUX" 100 || ! kill -0 "$pid" 2>/dev/null; then
        fail "Anland daemon 启动失败；查看 ${ANLAND_SOCKET_TERMUX%/*}/newhome-anland.log"
    fi

    # F-Droid/variant Termux uses Anland's Binder fd bridge in addition to the
    # daemon. Official GitHub Termux uses shared UID and does not need it.
    if [ "${TERMUX_APP__APK_RELEASE:-}" = "F_DROID" ]; then
        if command -v anland-compatible >/dev/null 2>&1; then
            anland-compatible >"${ANLAND_SOCKET_TERMUX%/*}/newhome-anland-compatible.log" 2>&1 &
        else
            fail "当前 Termux 需要 compatible APK，但 anland-compatible 不存在"
        fi
    fi
}

start_container() {
    if ! container_mounted; then
        log "启动 Debian chroot"
        start_chroot_container || fail "chroot 启动失败"
    else
        log "Debian chroot 已挂载，复用现有容器"
    fi
}

start_session() {
    log "启动 Labwc + XFCE Wayland session"
    chroot_exec -u root "pkill -x labwc >/dev/null 2>&1 || true; pkill -x weston >/dev/null 2>&1 || true; nohup env NEWHOME_WAYLAND_MODE=${NEWHOME_WAYLAND_MODE:-auto} /bin/bash $SESSION_SCRIPT >$SESSION_LOG 2>&1 </dev/null &"
    sleep 1

    # Manual tstart-wayland should be as convenient as the X11 profile. NewHome
    # repeats this foreground step after a privileged restart-wayland request.
    if ! am start --user 0 -n "$ANLAND_ANDROID_ACTIVITY" >/dev/null 2>&1; then
        log "警告：无法前置 Anland Termux Activity；请确认 APK 已安装"
    fi
}

start_all() {
    check_requirements
    start_anland
    start_container
    start_session
    log "Wayland 环境启动请求完成"
    log "架构模式: ${NEWHOME_WAYLAND_MODE:-auto} (direct backend 就绪后 auto 会自动跳过 Weston bootstrap)"
}

stop_all() {
    log "停止 Wayland/chroot 环境"
    stop_chroot_container 2>/dev/null || true
    stop_anland
    log "Wayland 环境已停止；Termux:X11 未被本脚本触碰"
}

status_all() {
    echo "=== NewHome Wayland profile ==="
    printf 'Anland daemon: '
    pgrep -x anland >/dev/null 2>&1 && echo '运行中' || echo '已停止'
    printf 'Anland socket: '
    [ -S "$ANLAND_SOCKET_TERMUX" ] && echo "$ANLAND_SOCKET_TERMUX" || echo '不存在'
    printf 'Anland Android app: '
    cmd package path "$ANLAND_ANDROID_PACKAGE" >/dev/null 2>&1 && echo '已安装' || echo '未安装'
    check_chroot_status || true
    if container_mounted; then
        echo "Wayland processes:"
        chroot_exec -u root "pgrep -a -x labwc; pgrep -a -x weston" 2>/dev/null || true
    fi
}

install_stack() {
    exec "$PREFIX/bin/bash" "$WAYLAND_DIR/install_anland_wayland.sh"
}

doctor() {
    exec "$PREFIX/bin/bash" "$WAYLAND_DIR/wayland_doctor.sh"
}

show_usage() {
    cat <<EOF
NewHome Anland Wayland 编排器

用法:
  $0 start       启动 Anland + chroot + Labwc/XFCE
  $0 stop        停止 Wayland profile（不触碰 Termux:X11）
  $0 restart     重启到 Wayland profile
  $0 status      查看状态
  $0 install     安装固定版本的 Anland/Labwc/Weston bootstrap
  $0 doctor      检查 Anland/GPU/Labwc/wlroots 环境

模式:
  NEWHOME_WAYLAND_MODE=auto    默认；优先 direct wlroots-anland，否则 nested Weston bootstrap
  NEWHOME_WAYLAND_MODE=direct  强制 Labwc -> wlroots-anland -> Anland
  NEWHOME_WAYLAND_MODE=nested  强制 Labwc -> Weston-Anland -> Anland
EOF
}

case "${1:-start}" in
    start) start_all ;;
    stop) stop_all ;;
    restart) stop_all; sleep 1; start_all ;;
    status) status_all ;;
    install) install_stack ;;
    doctor) doctor ;;
    -h|--help|help) show_usage ;;
    *) show_usage; exit 2 ;;
esac
