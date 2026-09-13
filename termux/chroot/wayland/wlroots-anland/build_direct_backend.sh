#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYLAND_DIR="$(dirname "$ROOT_DIR")"
WORK_DIR=${NEWHOME_WLROOTS_WORK:-/var/tmp/newhome-wlroots-anland}
PREFIX_DIR=${NEWHOME_WLROOTS_PREFIX:-/opt/newhome-wayland/wlroots-anland}
TRANSPORT_PREFIX=${NEWHOME_ANLAND_TRANSPORT_PREFIX:-/opt/newhome-wayland/anland-transport}
READY_MARKER=${NEWHOME_WLROOTS_ANLAND_MARKER:-/opt/newhome-wayland/wlroots-anland.ready}
BUILT_MARKER=${NEWHOME_WLROOTS_ANLAND_BUILT:-/opt/newhome-wayland/wlroots-anland.built}
PRESENTATION=${NEWHOME_ANLAND_PRESENTATION:-zero-copy}

. "$WAYLAND_DIR/anland_versions.sh"

log() { printf '[wlroots-anland-build] %s\n' "$*"; }
fail() { printf '[wlroots-anland-build] ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "请在 chroot root 环境运行"
case "$PRESENTATION" in
    zero-copy|stage3) ;;
    *) fail "未知 NEWHOME_ANLAND_PRESENTATION=$PRESENTATION（支持 zero-copy/stage3）" ;;
esac

install_deps() {
    export DEBIAN_FRONTEND=noninteractive
    local attempt
    for attempt in 1 2 3; do
        apt-get -o Acquire::Retries=8 update && break
        [ "$attempt" -lt 3 ] || fail "apt update 连续失败 3 次"
        log "apt update 失败，第 $attempt 次重试"
        sleep 1
    done
    for attempt in 1 2 3; do
        apt-get -o Acquire::Retries=8 install -y --no-install-recommends \
        ca-certificates curl xz-utils bzip2 patch git python3 \
        build-essential meson ninja-build pkg-config binutils devscripts dpkg-dev \
        libwayland-dev wayland-protocols libdrm-dev libgbm-dev \
        libegl1-mesa-dev libgles2-mesa-dev libpixman-1-dev \
        libxkbcommon-dev libinput-dev libudev-dev libseat-dev \
        libsystemd-dev libdisplay-info-dev libliftoff-dev hwdata \
        libvulkan-dev libxcb1-dev libxcb-render0-dev \
        libxcb-xfixes0-dev libxcb-errors-dev libxcb-icccm4-dev \
        libxcb-composite0-dev libxcb-res0-dev libxcb-xinput-dev \
        libxcb-ewmh-dev libxcb-dri3-dev libxcb-present-dev \
        libxcb-render-util0-dev libxcb-shm0-dev libxcb-xkb-dev \
        libx11-xcb-dev && break
        [ "$attempt" -lt 3 ] || fail "构建依赖安装连续失败 3 次"
        log "构建依赖安装失败，第 $attempt 次重试"
        sleep 1
    done
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

apply_common_overlays() {
    cd "$WORK_DIR/src"

    log "应用 wlroots 0.18.2 精确 base/output/reconnect overlay"
    python3 "$ROOT_DIR/apply_stage1_018.py" "$WORK_DIR/src"

    log "应用 pointer/keyboard/touch overlay"
    python3 "$ROOT_DIR/apply_stage2_input.py" "$WORK_DIR/src"
    # relative_direction was added after wlroots 0.18; keep the exact 0.18 axis ABI.
    sed -i '/^[[:space:]]*\.relative_direction[[:space:]]*=/d' backend/anland/input.c
    sed -i '/#include <stdlib.h>/a #include <string.h>' backend/anland/input.c

    mkdir -p backend/anland/vendor
    cp -f "$TRANSPORT_PREFIX/src/display_producer.c" backend/anland/vendor/
    cp -f "$TRANSPORT_PREFIX/src/socket_utils.c" backend/anland/vendor/
    cp -f "$TRANSPORT_PREFIX/include/display_producer.h" backend/anland/vendor/
    cp -f "$TRANSPORT_PREFIX/include/socket_utils.h" backend/anland/vendor/
    cp -f "$TRANSPORT_PREFIX/include/protocol.h" backend/anland/vendor/
    # On Linux EAGAIN and EWOULDBLOCK are equal; -Wlogical-op under -Werror
    # rejects testing both even though the vendored Android source is portable.
    sed -i 's/errno != EAGAIN && errno != EWOULDBLOCK/errno != EAGAIN/g' \
        backend/anland/vendor/display_producer.c
}

apply_stage4() {
    cd "$WORK_DIR/src"
    log "应用 Stage4 ZERO-COPY consumer DMA-BUF render-target overlay"
    python3 "$ROOT_DIR/apply_stage4_zero_copy.py" "$WORK_DIR/src"

    grep -Rqs "wlr_anland_backend_create" backend include || \
        fail "Stage4 未提供 wlr_anland_backend_create"
    grep -Rqs "anland_input_attach" backend/anland || \
        fail "Stage4 input overlay 未生效"
    grep -qs "acquire_render_buffer" include/wlr/interfaces/wlr_output.h || \
        fail "Stage4 未安装 wlroots render-target hook"
    grep -qs "output_acquire_render_buffer" types/output/render.c || \
        fail "Stage4 未接管 wlroots output render pass"
    grep -Rqs "anland_acquire_selected_buffer" backend/anland || \
        fail "Stage4 未提供 consumer DMA-BUF render target"
    grep -Rqs "Anland first zero-copy frame presented" backend/anland/output.c || \
        fail "Stage4 zero-copy presentation 路径缺失"
    grep -Rqs "get_drm_fd" backend/anland/backend.c || \
        fail "Stage4 未暴露 render-node fd"
    grep -Rqs "WLR_BUFFER_CAP_DMABUF" backend/anland/backend.c || \
        fail "Stage4 未限制为 DMA-BUF output"
    if grep -Rqs "anland_presenter_blit\|glFinish" backend/anland; then
        fail "Stage4 构建树仍包含 Stage3 fullscreen blit/glFinish"
    fi
}

apply_stage3_fallback() {
    cd "$WORK_DIR/src"
    # Stage3 is retained only as a diagnostic fallback for A/B and rollback.
    sed -i 's/return WLR_BUFFER_CAP_DATA_PTR | WLR_BUFFER_CAP_DMABUF | WLR_BUFFER_CAP_SHM;/return WLR_BUFFER_CAP_DATA_PTR | WLR_BUFFER_CAP_SHM;/' \
        backend/anland/backend.c
    log "应用 Stage3 GPU-only DMA-BUF blit fallback"
    python3 "$ROOT_DIR/apply_stage3_presentation.py" "$WORK_DIR/src"
    python3 "$ROOT_DIR/apply_stage3_018_fixups.py" "$WORK_DIR/src"

    grep -Rqs "anland_presenter_blit" backend/anland || \
        fail "Stage3 fallback presentation overlay 未生效"
    grep -Rqs "get_drm_fd" backend/anland/backend.c || \
        fail "Stage3 fallback 未暴露 render-node fd"
}

apply_overlays() {
    apply_common_overlays
    case "$PRESENTATION" in
        zero-copy) apply_stage4 ;;
        stage3) apply_stage3_fallback ;;
    esac
    grep -Rqs "ANLAND_SOCKET" "$WORK_DIR/src/backend" "$WORK_DIR/src/include" || \
        fail "overlay 未绑定 ANLAND_SOCKET"
}

build_install() {
    rm -rf "$PREFIX_DIR" "$READY_MARKER" "$BUILT_MARKER"
    mkdir -p "$PREFIX_DIR"
    cd "$WORK_DIR/src"

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

    log "检查 Anland backend 导出与依赖"
    local symbols
    symbols=$(nm -D "$lib")
    grep -q 'wlr_anland_backend_create' <<<"$symbols" || \
        fail "生成的 wlroots 库没有导出 wlr_anland_backend_create"

    if command -v labwc >/dev/null 2>&1; then
        local linked
        linked=$(ldd "$(command -v labwc)" | grep 'libwlroots-0.18' || true)
        log "系统 Labwc 当前 wlroots: ${linked:-未解析}"
    fi

    if [ "$PRESENTATION" = zero-copy ]; then
        cat > "$PREFIX_DIR/BUILD_INFO" <<EOF
stage=4-zero-copy
runtime_ready=no
presentation=direct-consumer-dmabuf-render-target
extra_fullscreen_gpu_blit=no
cpu_framebuffer_copy=no
synchronization=dma-buf-sync-file-to-anland-fence
anland=$ANLAND_VERSION
labwc_baseline=$NEWHOME_LABWC_BASELINE
wlroots=$NEWHOME_WLROOTS_BASELINE
wlroots_debian=$NEWHOME_WLROOTS_DEBIAN_BASELINE
transport_source=$(cat "$TRANSPORT_PREFIX/SOURCE" 2>/dev/null | tr '\n' ' ')
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
        printf 'stage4-zero-copy-built wlroots-anland %s / Anland %s\n' \
            "$NEWHOME_WLROOTS_BASELINE" "$ANLAND_VERSION" > "$BUILT_MARKER"
        log "Stage4 ZERO-COPY backend 已编译安装: $BUILT_MARKER"
        log "Labwc/wlroots 将直接渲染 Android consumer-selected DMA-BUF；无 Stage3 fullscreen blit/glFinish。"
    else
        cat > "$PREFIX_DIR/BUILD_INFO" <<EOF
stage=3-gpu-dmabuf-blit
runtime_ready=no
presentation=gpu-only-egl-dmabuf-blit
cpu_framebuffer_copy=no
synchronization=glFinish
anland=$ANLAND_VERSION
labwc_baseline=$NEWHOME_LABWC_BASELINE
wlroots=$NEWHOME_WLROOTS_BASELINE
wlroots_debian=$NEWHOME_WLROOTS_DEBIAN_BASELINE
transport_source=$(cat "$TRANSPORT_PREFIX/SOURCE" 2>/dev/null | tr '\n' ' ')
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
        printf 'stage3-built wlroots-anland %s / Anland %s\n' \
            "$NEWHOME_WLROOTS_BASELINE" "$ANLAND_VERSION" > "$BUILT_MARKER"
        log "Stage3 fallback backend 已编译安装: $BUILT_MARKER"
    fi

    log "构建成功不会自动写 $READY_MARKER。"
    log "运行 validate_direct_backend.sh，并确认 Android 画面后才启用 direct auto mode。"
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
