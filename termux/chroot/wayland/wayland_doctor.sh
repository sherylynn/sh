#!/data/data/com.termux/files/usr/bin/bash
set -u

PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
HOME=${HOME:-/data/data/com.termux/files/home}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHROOT_SCRIPT_DIR="$(dirname "$SCRIPT_DIR")"

. "$SCRIPT_DIR/anland_versions.sh"
set +e
. "$CHROOT_SCRIPT_DIR/cli.sh"
set -e

PASS=0
WARN=0
FAIL=0

ok() { printf '  [OK]   %s\n' "$*"; PASS=$((PASS + 1)); }
warn() { printf '  [WARN] %s\n' "$*"; WARN=$((WARN + 1)); }
bad() { printf '  [FAIL] %s\n' "$*"; FAIL=$((FAIL + 1)); }

check_termux() {
    echo '=== Termux / Android ==='
    if command -v anland >/dev/null 2>&1; then
        ok "anland daemon: $(command -v anland)"
    else
        bad "anland daemon 未安装"
    fi

    if cmd package path "$ANLAND_ANDROID_PACKAGE" >/dev/null 2>&1; then
        ok "Anland Android App 已安装 ($ANLAND_ANDROID_PACKAGE)"
    else
        bad "Anland Android App 未安装 ($ANLAND_ANDROID_PACKAGE)"
    fi

    if [ -e /dev/kgsl-3d0 ]; then
        [ -r /dev/kgsl-3d0 ] && ok '/dev/kgsl-3d0 可读' || warn '/dev/kgsl-3d0 存在但当前 UID 不可读'
    else
        warn '/dev/kgsl-3d0 不存在；SM8750 direct KGSL 路径不可用'
    fi

    if [ -e /dev/dri/renderD128 ]; then
        if [ -r /dev/dri/renderD128 ] && [ -w /dev/dri/renderD128 ]; then
            ok '/dev/dri/renderD128 可读写（Stage3 get_drm_fd 可用）'
        else
            warn '/dev/dri/renderD128 存在，但当前 Termux UID 不可读写'
        fi
    else
        warn '/dev/dri/renderD128 不存在；Stage3 render node 需要重新确认'
    fi

    if [ -S "$ANLAND_SOCKET_TERMUX" ]; then
        ok "Anland socket 已就绪: $ANLAND_SOCKET_TERMUX"
    else
        warn "Anland socket 尚未启动: $ANLAND_SOCKET_TERMUX"
    fi
}

check_chroot() {
    echo
    echo '=== Debian chroot ==='
    if ! container_mounted; then
        warn 'chroot 当前未挂载；只检查 Termux 侧'
        return
    fi

    local debian_version
    debian_version=$(chroot_exec -u root 'cat /etc/debian_version 2>/dev/null' 2>/dev/null | tail -n 1)
    case "$debian_version" in
        13*|trixie*) ok "Debian 13/trixie: $debian_version" ;;
        *) bad "当前不是 Debian 13/trixie: ${debian_version:-未知}" ;;
    esac

    if chroot_exec -u root 'command -v labwc >/dev/null 2>&1'; then
        local version
        version=$(chroot_exec -u root 'labwc --version 2>/dev/null | head -n1' 2>/dev/null || true)
        ok "Labwc: ${version:-已安装}"
    else
        bad 'Labwc 未安装'
    fi

    local wlr
    # Avoid dpkg-query's ${Version} format token here: chroot_exec passes the
    # command through another login shell, which would expand it too early.
    wlr=$(chroot_exec -u root "dpkg-query -W libwlroots-0.18 2>/dev/null | awk '{print \\$2}'" 2>/dev/null | tail -n 1)
    if [ -n "$wlr" ]; then
        case "$wlr" in
            "$NEWHOME_WLROOTS_DEBIAN_BASELINE"*) ok "系统 wlroots: $wlr" ;;
            *) warn "系统 wlroots=$wlr，direct backend 基线=$NEWHOME_WLROOTS_DEBIAN_BASELINE" ;;
        esac
    else
        bad 'libwlroots-0.18 未安装'
    fi
    if [ -S "$ANLAND_SOCKET_CHROOT" ]; then
        ok "chroot 可见 Anland socket: $ANLAND_SOCKET_CHROOT"
    else
        warn "chroot 当前看不到 $ANLAND_SOCKET_CHROOT"
    fi

    if chroot_exec -u root 'test -r /dev/dri/renderD128 && test -w /dev/dri/renderD128'; then
        ok 'chroot /dev/dri/renderD128 可读写'
    else
        warn 'chroot /dev/dri/renderD128 不可读写；direct GLES/GBM allocator 会失败'
    fi

    if chroot_exec -u root 'command -v weston >/dev/null 2>&1'; then
        if chroot_exec -u root 'strings "$(command -v weston)" 2>/dev/null | grep -q anland'; then
            ok 'Weston-Anland bootstrap 已安装'
        else
            warn 'weston 存在，但无法从二进制确认 Anland backend'
        fi
    else
        warn 'Weston-Anland bootstrap 未安装'
    fi

    if chroot_exec -u root 'test -f /opt/newhome-wayland/wlroots-anland.built'; then
        local build_info
        build_info=$(chroot_exec -u root 'cat /opt/newhome-wayland/wlroots-anland/BUILD_INFO 2>/dev/null' 2>/dev/null || true)
        if printf '%s\n' "$build_info" | grep -q 'stage=3-gpu-dmabuf-blit'; then
            ok 'direct wlroots-anland Stage3 已构建（GPU-only DMA-BUF blit）'
        else
            warn 'direct backend 有 built marker，但 BUILD_INFO 不是当前 Stage3'
        fi
    else
        warn 'direct wlroots-anland Stage3 尚未构建'
    fi

    if chroot_exec -u root 'test -f /opt/newhome-wayland/wlroots-anland.ready'; then
        local ready
        ready=$(chroot_exec -u root 'cat /opt/newhome-wayland/wlroots-anland.ready 2>/dev/null' 2>/dev/null || true)
        ok "direct wlroots-anland 已真机确认 ready: ${ready:-marker存在}"
    else
        warn 'direct Stage3 尚未真机确认；auto 模式继续使用 Weston bootstrap'
    fi

    if chroot_exec -u root 'test -f /tmp/newhome-wayland/direct-smoke.log'; then
        if chroot_exec -u root 'grep -q "Anland first GPU DMA-BUF frame presented successfully" /tmp/newhome-wayland/direct-smoke.log'; then
            ok '最近 direct smoke 已至少成功提交一帧到 Anland consumer'
        else
            warn '存在 direct smoke 日志，但尚未看到成功 presentation 标记'
        fi
    fi
}

check_profiles() {
    echo
    echo '=== 启动 profile ==='
    [ -f "$CHROOT_SCRIPT_DIR/termux_all_in_one.sh" ] && ok 'X11 profile 脚本存在' || bad '缺少 X11 profile'
    [ -f "$CHROOT_SCRIPT_DIR/termux_wayland_all_in_one.sh" ] && ok 'Wayland profile 脚本存在' || bad '缺少 Wayland profile'

    if container_mounted && chroot_exec -u root 'test -f /root/sh/termux/chroot/newhome_control.py'; then
        ok 'NewHome control client 在 chroot 可见'
    fi
}

check_termux
check_chroot
check_profiles

echo
printf '结果: OK=%d WARN=%d FAIL=%d\n' "$PASS" "$WARN" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
