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

# Display profiles are mutually exclusive. Leaving the runit-managed X server
# alive lets Termux:X11 reclaim the foreground while Anland is connecting.
quiesce_x11_profile() {
    log "停止 X11 profile，避免 Termux:X11 抢占 Wayland 前台"
    for service in x11 tx11 tx11-xfce4; do
        [ -d "$PREFIX/var/service/$service" ] && sv down "$service" >/dev/null 2>&1 || true
    done
    killall -TERM termux-x11 >/dev/null 2>&1 || true
    pkill -TERM -f 'termux-x11 com\.termux\.x11 :[0-9]+' >/dev/null 2>&1 || true
    sleep 0.2
    killall -KILL termux-x11 >/dev/null 2>&1 || true
    pkill -KILL -f 'termux-x11 com\.termux\.x11 :[0-9]+' >/dev/null 2>&1 || true
    am broadcast --user 0 -a com.termux.x11.ACTION_STOP -p com.termux.x11 >/dev/null 2>&1 || true
    am force-stop --user 0 com.termux.x11 >/dev/null 2>&1 || true
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

# Verify the bind semantically instead of trusting the root mount alone. Android
# can leave /data/local/mnt mounted while an individual child mount has vanished.
# A temporary marker proves that Termux $PREFIX/tmp and chroot's host-side /tmp
# are the same live directory; this also avoids relying on /proc/mounts' bind
# source string, which may be reported as the underlying device instead.
tmp_bridge_visible() {
    container_mounted || return 1
    local source_dir="$PREFIX/tmp"
    local target_dir="$CHROOT_DIR/tmp"
    local marker=".newhome-anland-mount-probe.$$"
    local token="newhome-anland-$$-$(date +%s)"

    [ -d "$source_dir" ] || return 1
    [ -d "$target_dir" ] || return 1

    printf '%s\n' "$token" >"$source_dir/$marker" || return 1
    local visible=1
    if [ -f "$target_dir/$marker" ] && [ "$(cat "$target_dir/$marker" 2>/dev/null)" = "$token" ]; then
        visible=0
    fi
    rm -f "$source_dir/$marker" "$target_dir/$marker" 2>/dev/null || true
    return "$visible"
}

chroot_anland_socket_visible() {
    container_mounted || return 1
    chroot_exec -u root "test -S '$ANLAND_SOCKET_CHROOT'" >/dev/null 2>&1
}

repair_tmp_bridge() {
    container_mounted || return 1
    local target="$CHROOT_DIR/tmp"

    log "检测到 chroot /tmp 未正确共享 Termux tmp，尝试原位修复"
    sudo mkdir -p "$target" || return 1

    if is_mounted "$target"; then
        # Do not use lazy/force unmount here: if a live process makes /tmp busy,
        # fall back to a clean container restart instead of creating split views.
        sudo "$busybox" umount "$target" >/dev/null 2>&1 || \
            sudo umount "$target" >/dev/null 2>&1 || return 1
    fi

    mount_part tmp || return 1
    tmp_bridge_visible
}

ensure_anland_bridge() {
    [ -S "$ANLAND_SOCKET_TERMUX" ] || {
        log "Anland host socket 尚未出现: $ANLAND_SOCKET_TERMUX"
        return 1
    }

    if ! tmp_bridge_visible; then
        repair_tmp_bridge || return 1
    fi

    if ! chroot_anland_socket_visible; then
        log "Termux socket 存在，但 chroot 仍看不到 $ANLAND_SOCKET_CHROOT"
        return 1
    fi

    log "Anland /tmp bridge 已验证: $ANLAND_SOCKET_TERMUX -> $ANLAND_SOCKET_CHROOT"
    return 0
}

start_container() {
    if ! container_mounted; then
        log "启动 Debian chroot"
        start_chroot_container || fail "chroot 启动失败"
    else
        log "Debian chroot root mount 已存在，验证 Wayland 所需 /tmp bridge"
    fi

    if ensure_anland_bridge; then
        log "Debian chroot 可安全复用"
        return 0
    fi

    # A missing child bind mount can sometimes be repaired in place. If that
    # failed (busy mount, stale namespace, partial Android reclaim), do one
    # clean container restart while keeping the already-running Anland daemon.
    log "现有 chroot 无法安全复用，执行一次完整 chroot 重挂载"
    stop_chroot_container 2>/dev/null || true
    sleep 1
    start_chroot_container || fail "chroot 重挂载失败"
    ensure_anland_bridge || fail "chroot 重挂载后仍看不到 Anland socket；请运行 status/doctor 查看三层状态"
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
    quiesce_x11_profile
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

print_bridge_status() {
    printf 'Host Anland socket: '
    [ -S "$ANLAND_SOCKET_TERMUX" ] && echo "OK ($ANLAND_SOCKET_TERMUX)" || echo "MISSING ($ANLAND_SOCKET_TERMUX)"

    printf 'Termux tmp -> chroot /tmp: '
    if container_mounted && tmp_bridge_visible; then
        echo "OK ($PREFIX/tmp -> $CHROOT_DIR/tmp)"
    elif container_mounted; then
        echo "BROKEN/NOT-MOUNTED ($PREFIX/tmp -> $CHROOT_DIR/tmp)"
    else
        echo 'N/A (chroot 未挂载)'
    fi

    printf 'Chroot Anland socket: '
    if container_mounted && chroot_anland_socket_visible; then
        echo "OK ($ANLAND_SOCKET_CHROOT)"
    elif container_mounted; then
        echo "MISSING ($ANLAND_SOCKET_CHROOT)"
    else
        echo 'N/A (chroot 未挂载)'
    fi
}

status_all() {
    echo "=== NewHome Wayland profile ==="
    printf 'Anland daemon: '
    pgrep -x anland >/dev/null 2>&1 && echo '运行中' || echo '已停止'
    printf 'Anland Android app: '
    cmd package path "$ANLAND_ANDROID_PACKAGE" >/dev/null 2>&1 && echo '已安装' || echo '未安装'
    print_bridge_status
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
    # build itself doesn't need Anland running, but if an already-mounted
    # container is being reused, keep its /tmp semantics correct for the later
    # direct validation path.
    if container_mounted && ! tmp_bridge_visible; then
        repair_tmp_bridge || log "警告：build-direct 前无法原位修复 /tmp；构建仍可继续，真机验证前会强制重挂载"
    fi
    if ! container_mounted; then
        start_chroot_container || fail "chroot 启动失败"
    fi
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
  $0 restart          重启到 Wayland profile，并重建/校验 Anland /tmp bridge
  $0 status           查看 host socket / tmp bind / chroot socket 三层状态
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
