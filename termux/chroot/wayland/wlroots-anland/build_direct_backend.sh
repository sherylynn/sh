#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYLAND_DIR="$(dirname "$ROOT_DIR")"
WORK_DIR=${NEWHOME_WLROOTS_WORK:-/var/tmp/newhome-wlroots-anland}
PREFIX_DIR=${NEWHOME_WLROOTS_PREFIX:-/opt/newhome-wayland/wlroots-anland}
TRANSPORT_PREFIX=${NEWHOME_ANLAND_TRANSPORT_PREFIX:-/opt/newhome-wayland/anland-transport}
READY_MARKER=${NEWHOME_WLROOTS_ANLAND_MARKER:-/opt/newhome-wayland/wlroots-anland.ready}
PATCH_DIR="$ROOT_DIR/patches"

# shellcheck source=../anland_versions.sh
. "$WAYLAND_DIR/anland_versions.sh"

log() { printf '[wlroots-anland-build] %s\n' "$*"; }
fail() { printf '[wlroots-anland-build] ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "请在 chroot root 环境运行"

install_deps() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
        ca-certificates curl xz-utils bzip2 patch git \
        build-essential meson ninja-build pkg-config \
        libwayland-dev wayland-protocols libdrm-dev libgbm-dev \
        libegl1-mesa-dev libgles2-mesa-dev libpixman-1-dev \
        libxkbcommon-dev libinput-dev libudev-dev libseat-dev \
        libsystemd-dev libdisplay-info-dev libliftoff-dev \
        libvulkan-dev libxcb1-dev libxcb-render0-dev \
        libxcb-xfixes0-dev libxcb-errors-dev libxcb-icccm4-dev \
        libxcb-composite0-dev libxcb-res0-dev libxcb-xinput-dev \
        libxcb-ewmh-dev libxcb-dri3-dev libxcb-present-dev \
        libxcb-render-util0-dev libxcb-shm0-dev libxcb-xkb-dev \
        libx11-xcb-dev
}

prepare_transport() {
    if [ ! -f "$TRANSPORT_PREFIX/include/display_producer.h" ] || \
       [ ! -f "$TRANSPORT_PREFIX/src/display_producer.c" ]; then
        log "准备固定 Anland 5.13 producer transport"
        "$ROOT_DIR/prepare_transport.sh"
    fi
}

fetch_source() {
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"

    local orig="wlroots_${NEWHOME_WLROOTS_BASELINE}.orig.tar.bz2"
    local debian="wlroots_${NEWHOME_WLROOTS_DEBIAN_BASELINE}.debian.tar.xz"
    local pool="https://deb.debian.org/debian/pool/main/w/wlroots"

    log "下载 Debian 13 wlroots ${NEWHOME_WLROOTS_DEBIAN_BASELINE} 源码"
    curl -fL --retry 3 "$pool/$orig" -o "$orig"
    curl -fL --retry 3 "$pool/$debian" -o "$debian"

    mkdir src
    tar -xjf "$orig" -C src --strip-components=1
    tar -xJf "$debian" -C src

    grep -q "version: '${NEWHOME_WLROOTS_BASELINE}'" src/meson.build || \
        fail "下载的 wlroots 源码版本不是 ${NEWHOME_WLROOTS_BASELINE}"
}

apply_patches() {
    [ -d "$PATCH_DIR" ] || fail "缺少 patch 目录: $PATCH_DIR"
    local series="$PATCH_DIR/series"
    [ -f "$series" ] || fail "缺少 patch series: $series"

    cd "$WORK_DIR/src"
    while IFS= read -r patch_name; do
        case "$patch_name" in
            ''|'#'*) continue ;;
        esac
        [ -f "$PATCH_DIR/$patch_name" ] || fail "缺少 patch: $patch_name"
        log "应用 $patch_name"
        patch -p1 --forward --batch < "$PATCH_DIR/$patch_name"
    done < "$series"

    # The direct backend is not considered real until the source tree exposes
    # the explicit Anland backend symbol and transport implementation. This
    # prevents an empty/scaffold patchset from accidentally creating .ready.
    grep -Rqs "wlr_anland_backend_create" backend include || \
        fail "patchset 尚未提供 wlr_anland_backend_create；拒绝构建 ready backend"
    grep -Rqs "ANLAND_SOCKET" backend include || \
        fail "patchset 未绑定 ANLAND_SOCKET；拒绝构建"
}

build_install() {
    rm -rf "$PREFIX_DIR" "$READY_MARKER"
    mkdir -p "$PREFIX_DIR"
    cd "$WORK_DIR/src"

    # Anland transport source is intentionally copied into the wlroots source
    # tree by the patch/build contract rather than dynamically linked against
    # Weston. wlroots then owns exactly one producer implementation.
    mkdir -p backend/anland/vendor
    cp -f "$TRANSPORT_PREFIX/src/display_producer.c" backend/anland/vendor/
    cp -f "$TRANSPORT_PREFIX/src/socket_utils.c" backend/anland/vendor/
    cp -f "$TRANSPORT_PREFIX/include/display_producer.h" backend/anland/vendor/
    cp -f "$TRANSPORT_PREFIX/include/socket_utils.h" backend/anland/vendor/
    cp -f "$TRANSPORT_PREFIX/include/protocol.h" backend/anland/vendor/

    meson setup build \
        --prefix="$PREFIX_DIR" \
        --libdir=lib \
        --buildtype=release \
        -Dexamples=false \
        -Dwerror=true
    ninja -C build
    ninja -C build install
}

validate_install() {
    local lib
    lib=$(find "$PREFIX_DIR/lib" -maxdepth 1 -type f -name 'libwlroots-0.18.so*' | head -n 1 || true)
    [ -n "$lib" ] || fail "安装目录没有 libwlroots-0.18"

    log "检查 direct backend 符号"
    nm -D "$lib" | grep -q 'wlr_anland_backend_create' || \
        fail "生成的 wlroots 库没有导出 wlr_anland_backend_create"

    if command -v labwc >/dev/null 2>&1; then
        local linked
        linked=$(ldd "$(command -v labwc)" | grep 'libwlroots-0.18' || true)
        log "系统 Labwc 当前 wlroots: ${linked:-未解析}"
    fi

    cat > "$PREFIX_DIR/BUILD_INFO" <<EOF
anland=$ANLAND_VERSION
labwc_baseline=$NEWHOME_LABWC_BASELINE
wlroots=$NEWHOME_WLROOTS_BASELINE
wlroots_debian=$NEWHOME_WLROOTS_DEBIAN_BASELINE
transport_source=$(cat "$TRANSPORT_PREFIX/SOURCE" 2>/dev/null | tr '\n' ' ')
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

    # Marker is written last. start_labwc_anland.sh uses it as the only signal
    # that auto mode may attempt the direct backend.
    printf 'wlroots-anland %s / Anland %s\n' \
        "$NEWHOME_WLROOTS_BASELINE" "$ANLAND_VERSION" > "$READY_MARKER"
    log "direct backend 已安装并标记 ready: $READY_MARKER"
}

main() {
    install_deps
    prepare_transport
    fetch_source
    apply_patches
    build_install
    validate_install
}

main "$@"
