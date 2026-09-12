#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
HOME=${HOME:-/data/data/com.termux/files/home}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHROOT_DIR_SCRIPT="$(dirname "$SCRIPT_DIR")"
CACHE_DIR="${NEWHOME_WAYLAND_CACHE:-$HOME/.cache/newhome-wayland}"
SHARED_DIR="$PREFIX/tmp/newhome-wayland-packages"

# shellcheck source=anland_versions.sh
. "$SCRIPT_DIR/anland_versions.sh"
# shellcheck source=../cli.sh
set +e
. "$CHROOT_DIR_SCRIPT/cli.sh"
set -e

log() { printf '[wayland-install] %s\n' "$*"; }
fail() { printf '[wayland-install] ERROR: %s\n' "$*" >&2; exit 1; }

need_termux_tooling() {
    command -v curl >/dev/null 2>&1 || pkg install -y curl
    command -v unzip >/dev/null 2>&1 || pkg install -y unzip
    command -v sha256sum >/dev/null 2>&1 || pkg install -y coreutils
    mkdir -p "$CACHE_DIR" "$SHARED_DIR"
}

download() {
    local name=$1
    local target="$CACHE_DIR/$name"
    if [ ! -s "$target" ]; then
        log "下载 $name" >&2
        curl -fL --retry 3 --connect-timeout 15 \
            "$ANLAND_RELEASE_BASE/$name" -o "$target"
    fi
    printf '%s\n' "$target"
}

verify_sha256() {
    local file=$1 expected=$2
    local actual
    actual=$(sha256sum "$file" | awk '{print $1}')
    [ "$actual" = "$expected" ] || fail "SHA-256 不匹配: $(basename "$file")"
}

choose_apk() {
    # Official GitHub Termux can use Anland's shared-UID fast path. F-Droid and
    # variants need the compatible APK + anland-compatible Binder bridge.
    if [ "${TERMUX_APP__APK_RELEASE:-}" = "F_DROID" ]; then
        printf '%s\n' "$ANLAND_APK_COMPATIBLE"
    else
        printf '%s\n' "$ANLAND_APK_STANDARD"
    fi
}

install_termux_side() {
    local apk_name apk daemon
    apk_name=$(choose_apk)
    apk=$(download "$apk_name")
    daemon=$(download "$ANLAND_DAEMON_DEB")

    if [ "$apk_name" = "$ANLAND_APK_COMPATIBLE" ]; then
        verify_sha256 "$apk" "$ANLAND_APK_COMPATIBLE_SHA256"
    else
        verify_sha256 "$apk" "$ANLAND_APK_STANDARD_SHA256"
    fi
    verify_sha256 "$daemon" "$ANLAND_DAEMON_DEB_SHA256"

    log "安装/更新 Termux Anland daemon $ANLAND_VERSION"
    apt install -y "$daemon"

    mkdir -p "$HOME/storage/downloads" 2>/dev/null || true
    cp -f "$apk" "$HOME/storage/downloads/$apk_name" 2>/dev/null || true
    log "Android APK 已准备: $apk"
    log "当前 Termux 类型选择: $apk_name"
    log "如尚未安装，请在 Android 中安装该 APK；不要同时安装 standard/compatible 两个变体。"
}

ensure_container_started() {
    if ! container_mounted; then
        log "挂载并启动现有 Debian chroot"
        start_chroot_container
    fi
}

install_container_side() {
    local xwayland weston_zip
    xwayland=$(download "$ANLAND_DEBIAN_XWAYLAND_DEB")
    weston_zip=$(download "$ANLAND_DEBIAN_WESTON_ZIP")
    verify_sha256 "$xwayland" "$ANLAND_DEBIAN_XWAYLAND_SHA256"
    verify_sha256 "$weston_zip" "$ANLAND_DEBIAN_WESTON_SHA256"
    cp -f "$xwayland" "$SHARED_DIR/"
    cp -f "$weston_zip" "$SHARED_DIR/"

    ensure_container_started

    log "确认容器为 Debian 13/trixie"
    chroot_exec -u root 'grep -Eq "^(13|trixie)" /etc/debian_version /etc/os-release 2>/dev/null || { echo "需要 Debian 13/trixie chroot" >&2; exit 20; }'

    log "安装 Labwc + XFCE 用户体验层"
    chroot_exec -u root 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y labwc xfce4-panel xfce4-terminal xfce4-settings xfce4-notifyd thunar dbus-x11 unzip procps coreutils pipewire-audio python3 python3-gi gir1.2-gtk-3.0 libnotify-bin'

    log "安装 Anland 5.13.3 对应 Debian 13 XWayland/Weston bootstrap 包"
    chroot_exec -u root "set -e; cd /tmp/newhome-wayland-packages; apt-get install -y ./$ANLAND_DEBIAN_XWAYLAND_DEB; rm -rf weston-anland-debs; mkdir weston-anland-debs; unzip -oq ./$ANLAND_DEBIAN_WESTON_ZIP -d weston-anland-debs; apt-get install -y ./weston-anland-debs/*.deb"

    # Labwc uses its own config directory so the experiment does not disturb an
    # existing X11/XFCE configuration.
    chroot_exec -u root 'install -d -m 0700 /root/.config/newhome-labwc'
    chroot_exec -u root 'cat > /root/.config/newhome-labwc/autostart <<"EOF"
#!/bin/sh
xfsettingsd --replace >/tmp/newhome-wayland-xfsettings.log 2>&1 &
xfce4-notifyd >/tmp/newhome-wayland-notify.log 2>&1 &
thunar --daemon >/tmp/newhome-wayland-thunar.log 2>&1 &
xfce4-panel >/tmp/newhome-wayland-panel.log 2>&1 &
python3 /root/sh/win-git/wayland_profile_tray.py >/tmp/newhome-wayland-tray.log 2>&1 &
EOF
chmod +x /root/.config/newhome-labwc/autostart'

    chroot_exec -u root 'cat > /root/.config/newhome-labwc/environment <<"EOF"
XDG_CURRENT_DESKTOP=XFCE
XDG_SESSION_DESKTOP=XFCE
XDG_SESSION_TYPE=wayland
GDK_BACKEND=wayland,x11
QT_QPA_PLATFORM=wayland;xcb
XCURSOR_SIZE=24
EOF'

    log "容器端安装完成"
    log "注意：Anland 的 Wayland/KGSL 路径要求支持 KGSL Wayland 的 Mesa。若当前 Mesa 较旧，先按 lfdevs/mesa-for-android-container 最新说明升级。"
}

main() {
    need_termux_tooling
    install_termux_side
    install_container_side
    cat <<EOF

Wayland bootstrap 已安装。
  Anland: $ANLAND_VERSION
  Labwc baseline: Debian 13 package ($NEWHOME_LABWC_BASELINE / wlroots $NEWHOME_WLROOTS_BASELINE)

启动测试：
  bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh doctor
  bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh start

当前脚本会在 direct wlroots-anland backend 尚未 ready 时使用：
  Anland -> Weston(anland backend) -> Labwc -> XFCE components

后续 direct backend 安装并通过校验后，同一启动脚本自动切换为：
  Anland -> wlroots(anland backend) -> Labwc -> XFCE components

Wayland 会话内提供独立托盘，可从桌面直接重启回 X11。
EOF
}

main "$@"
