#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYLAND_DIR="$(dirname "$ROOT_DIR")"
WORK_DIR=${NEWHOME_WLROOTS_WORK:-/var/tmp/newhome-wlroots-anland}
PREFIX_DIR=${NEWHOME_WLROOTS_PREFIX:-/opt/newhome-wayland/wlroots-anland}
TRANSPORT_PREFIX=${NEWHOME_ANLAND_TRANSPORT_PREFIX:-/opt/newhome-wayland/anland-transport}
READY_MARKER=${NEWHOME_WLROOTS_ANLAND_MARKER:-/opt/newhome-wayland/wlroots-anland.ready}
BUILT_MARKER=${NEWHOME_WLROOTS_ANLAND_BUILT:-/opt/newhome-wayland/wlroots-anland.built}

# shellcheck source=../anland_versions.sh
. "$WAYLAND_DIR/anland_versions.sh"

log() { printf '[wlroots-anland-build] %s\n' "$*"; }
fail() { printf '[wlroots-anland-build] ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "请在 chroot root 环境运行"

install_deps() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
        ca-certificates curl xz-utils bzip2 patch git python3 \
        build-essential meson ninja-build pkg-config binutils devscripts dpkg-dev \
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
        /bin/bash "$ROOT_DIR/prepare_transport.sh"
    fi
}

fetch_source() {
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"

    local dsc="https://deb.debian.org/debian/pool/main/w/wlroots/wlroots_${NEWHOME_WLROOTS_DEBIAN_BASELINE}.dsc"
    log "通过 Debian .dsc 获取 wlroots ${NEWHOME_WLROOTS_DEBIAN_BASELINE} 精确源码"
    dget -u "$dsc"

    local src
    src=$(find "$WORK_DIR" -maxdepth 1 -type d -name "wlroots-${NEWHOME_WLROOTS_BASELINE}*" | head -n1 || true)
    [ -n "$src" ] || fail "dget/dpkg-source 后未找到 wlroots 源码目录"
    mv "$src" "$WORK_DIR/src"

    grep -q "version: '${NEWHOME_WLROOTS_BASELINE}'" "$WORK_DIR/src/meson.build" || \
        fail "下载的 wlroots 源码版本不是 ${NEWHOME_WLROOTS_BASELINE}"
}

apply_overlays() {
    cd "$WORK_DIR/src"

    log "应用 stage1 output/reconnect overlay"
    python3 "$ROOT_DIR/apply_stage1_overlay.py" "$WORK_DIR/src"

    # wlroots 0.18 has no standalone wlr_output_finish() helper. The output was
    # never published on this allocation-failure branch, so remove the stale
    # stage1 cleanup call before compiling rather than depending on an implicit
    # symbol.
    sed -i '/^[[:space:]]*wlr_output_finish(&output->wlr_output);[[:space:]]*$/d' \
        backend/anland/output.c

    log "应用 stage2 pointer/keyboard/touch overlay"
    python3 "$ROOT_DIR/apply_stage2_input.py" "$WORK_DIR/src"
    sed -i '/#include <stdlib.h>/a #include <string.h>' backend/anland/input.c

    grep -Rqs "wlr_anland_backend_create" backend include || \
        fail "overlay 未提供 wlr_anland_backend_create"
    grep -Rqs "anland_input_attach" backend/anland || \
        fail "stage2 input overlay 未生效"
    grep -Rqs "ANLAND_SOCKET" backend include || \
        fail "overlay 未绑定 ANLAND_SOCKET"

    # Exact producer implementation is copied after the structural overlays.
    mkdir -p backend/anland/vendor
    cp -f "$TRANSPORT_PREFIX/src/display_producer.c" backend/anland/vendor/
    cp -f "$TRANSPORT_PREFIX/src/socket_utils.c" backend/anland/vendor/
    cp -f "$TRANSPORT_PREFIX/include/display_producer.h" backend/anland/vendor/
    cp -f "$TRANSPORT_PREFIX/include/socket_utils.h" backend/anland/vendor/
    cp -f "$TRANSPORT_PREFIX/include/protocol.h" backend/anland/vendor/
}

build_install() {
    rm -rf "$PREFIX_DIR" "$READY_MARKER" "$BUILT_MARKER"
    mkdir -p "$PREFIX_DIR"
    cd "$WORK_DIR/src"

    # Stages 1-2 deliberately stop before framebuffer presentation. Stage 3
    # supplies the GPU/DMA-BUF output path. Build success here never means the
    # direct desktop may be auto-selected.
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
    lib=$(find "$PREFIX_DIR/lib" -maxdepth 1 \( -type f -o -type l \) -name 'libwlroots-0.18.so*' | head -n 1 || true)
    [ -n "$lib" ] || fail "安装目录没有 libwlroots-0.18"

    log "检查 Anland backend 导出符号"
    nm -D "$lib" | grep -q 'wlr_anland_backend_create' || \
        fail "生成的 wlroots 库没有导出 wlr_anland_backend_create"

    if command -v labwc >/dev/null 2>&1; then
        local linked
        linked=$(ldd "$(command -v labwc)" | grep 'libwlroots-0.18' || true)
        log "系统 Labwc 当前 wlroots: ${linked:-未解析}"
    fi

    cat > "$PREFIX_DIR/BUILD_INFO" <<EOF
stage=2-output-input
runtime_ready=no
presentation=not-implemented
anland=$ANLAND_VERSION
labwc_baseline=$NEWHOME_LABWC_BASELINE
wlroots=$NEWHOME_WLROOTS_BASELINE
wlroots_debian=$NEWHOME_WLROOTS_DEBIAN_BASELINE
transport_source=$(cat "$TRANSPORT_PREFIX/SOURCE" 2>/dev/null | tr '\n' ' ')
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

    printf 'stage2 wlroots-anland %s / Anland %s\n' \
        "$NEWHOME_WLROOTS_BASELINE" "$ANLAND_VERSION" > "$BUILT_MARKER"
    log "stage2 backend 已编译安装: $BUILT_MARKER"
    log "已覆盖 output discovery/reconnect + pointer/keyboard/touch。"
    log "DMA-BUF presentation 尚未实现，因此不会写入 $READY_MARKER。"
    log "auto 模式继续安全使用 Weston bootstrap。"
}

main() {
    install_deps
    prepare_transport
    fetch_source
    apply_overlays
    build_install
    validate_install
}

main "$@"
