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
DIRECT_DIR="/root/sh/termux/chroot/wayland/wlroots-anland"

. "$WAYLAND_DIR/anland_versions.sh"
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

foreground_anland() {
    if ! am start --user 0 -n "$ANLAND_ANDROID_ACTIVITY" >/dev/null 2>&1; then
        log "警告：无法前置 Anland Termux Activity；请确认 APK 已安装"
        return 1
    fi
}

start_session() {
    log "启动 Labwc + XFCE Wayland session"
    chroot_exec -u root "pkill -x labwc >/dev/null 2>&1 || true; pkill -x weston >/dev/null 2>&1 || true; nohup env NEWHOME_WAYLAND_MODE=${NEWHOME_WAYLAND_MODE:-auto} /bin/bash $SESSION_SCRIPT >$SESSION_LOG 2>&1 </dev/null &"
    sleep 1
    foreground_anland || true
}

start_all() {
    check_requirements
    start_anland
    start_container
    start_session
    log "Wayland 环境启动请求完成"
    log "架构模式: ${NEWHOME_WAYLAND_MODE:-auto} (Stage3 ready 后 auto 会直接使用 wlroots-anland)"
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
        chroot_exec -u root 'echo -n "Stage3 built: "; test -f /opt/newhome-wayland/wlroots-anland.built && cat /opt/newhome-wayland/wlroots-anland.built || echo no; echo -n "Direct ready: "; test -f /opt/newhome-wayland/wlroots-anland.ready && cat /opt/newhome-wayland/wlroots-anland.ready || echo no' 2>/dev/null || true
    fi
}

install_stack() {
    exec "$PREFIX/bin/bash" "$WAYLAND_DIR/install_anland_wayland.sh"
}

doctor() {
    exec "$PREFIX/bin/bash" "$WAYLAND_DIR/wayland_doctor.sh"
}

build_direct() {
    check_requirements
    start_container
    log "在 Debian chroot 中构建 wlroots-anland Stage3"
    chroot_exec -u root "/bin/bash $DIRECT_DIR/build_direct_backend.sh"
}

prepare_direct_smoke() {
    check_requirements
    start_anland
    start_container
    chroot_exec -u root 'pkill -TERM -x labwc >/dev/null 2>&1 || true; pkill -TERM -x weston >/dev/null 2>&1 || true'
    sleep 0.5
    foreground_anland || fail "Anland Android Activity 无法拉起"
    sleep 0.5
}

validate_direct() {
    prepare_direct_smoke
    log "运行 Stage3 direct smoke（不会写 ready marker）"
    chroot_exec -u root "/bin/bash $DIRECT_DIR/validate_direct_backend.sh"
}

activate_direct() {
    prepare_direct_smoke
    log "运行 Stage3 direct smoke，并在通过后记录你已确认 Android 画面可见"
    chroot_exec -u root "/bin/bash $DIRECT_DIR/validate_direct_backend.sh --accept-visible"
}

show_usage() {
    cat <<EOF
NewHome Anland Wayland 编排器

用法:
  $0 start            启动 Anland + chroot + Labwc/XFCE
  $0 stop             停止 Wayland profile（不触碰 Termux:X11）
  $0 restart          重启到 Wayland profile
  $0 status           查看状态
  $0 install          安装固定版本 Anland/Labwc/Weston bootstrap
  $0 doctor           检查 Anland/GPU/Labwc/wlroots/Stage3 状态
  $0 build-direct     构建 wlroots-anland Stage3（不会启用 direct）
  $0 validate-direct  真机 direct smoke；要求至少成功提交一帧，不写 ready
  $0 activate-direct  再次 smoke，并在你已确认画面可见后写 ready

模式:
  NEWHOME_WAYLAND_MODE=auto    默认；Stage3 ready 后 direct，否则 nested Weston
  NEWHOME_WAYLAND_MODE=direct  强制 Labwc -> wlroots-anland -> Anland（仍要求 ready marker）
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
    build-direct) build_direct ;;
    validate-direct) validate_direct ;;
    activate-direct) activate_direct ;;
    -h|--help|help) show_usage ;;
    *) show_usage; exit 2 ;;
esac
