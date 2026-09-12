#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR=${NEWHOME_ANLAND_TRANSPORT_WORK:-/var/tmp/newhome-anland-transport}
PREFIX_DIR=${NEWHOME_ANLAND_TRANSPORT_PREFIX:-/opt/newhome-wayland/anland-transport}
WESTON_REPO=${NEWHOME_ANLAND_WESTON_REPO:-https://github.com/lfdevs/weston.git}
WESTON_COMMIT=${NEWHOME_ANLAND_WESTON_COMMIT:-7db96561fb5fcbbe99132230bf73ed6988e92258}

log() { printf '[anland-transport] %s\n' "$*"; }
fail() { printf '[anland-transport] ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "请在 chroot root 环境运行"
[ -S /tmp/anland/display_daemon.sock ] || log "提示：Anland daemon socket 当前不存在；可以先构建，运行 probe 前再启动 Wayland profile"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates git quilt build-essential pkg-config

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$PREFIX_DIR/bin" "$PREFIX_DIR/include" "$PREFIX_DIR/lib" "$PREFIX_DIR/src"

log "获取固定 Weston/Anland producer 源码 $WESTON_COMMIT"
git clone --filter=blob:none --no-checkout "$WESTON_REPO" "$WORK_DIR/weston"
git -C "$WORK_DIR/weston" checkout --detach "$WESTON_COMMIT"

log "应用 lfdevs Debian Anland patch series"
(
    cd "$WORK_DIR/weston"
    export QUILT_PATCHES=debian/patches
    quilt push -a
)

VENDOR="$WORK_DIR/weston/libweston/backend-anland/vendor"
[ -f "$VENDOR/display_producer.c" ] || fail "应用 patch 后未找到 display_producer.c"
[ -f "$VENDOR/display_producer.h" ] || fail "应用 patch 后未找到 display_producer.h"
[ -f "$VENDOR/protocol.h" ] || fail "应用 patch 后未找到 protocol.h"
[ -f "$VENDOR/socket_utils.c" ] || fail "应用 patch 后未找到 socket_utils.c"

log "锁定 transport 源码快照"
cp -f "$VENDOR/display_producer.c" "$PREFIX_DIR/src/"
cp -f "$VENDOR/display_producer.h" "$PREFIX_DIR/include/"
cp -f "$VENDOR/protocol.h" "$PREFIX_DIR/include/"
cp -f "$VENDOR/socket_utils.c" "$PREFIX_DIR/src/"
cp -f "$VENDOR/socket_utils.h" "$PREFIX_DIR/include/"

cat > "$PREFIX_DIR/SOURCE" <<EOF
weston_repo=$WESTON_REPO
weston_commit=$WESTON_COMMIT
anland_protocol=5.13.x
prepared_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

log "构建 standalone Anland transport probe"
cc \
    -std=gnu11 -O2 -g \
    -Wall -Wextra -Werror \
    -DANLAND_BUF_INFO_HAS_DIMENSIONS=1 \
    -I"$PREFIX_DIR/include" \
    "$ROOT_DIR/anland_probe.c" \
    "$PREFIX_DIR/src/display_producer.c" \
    "$PREFIX_DIR/src/socket_utils.c" \
    -o "$PREFIX_DIR/bin/anland-probe"

log "检查生成物"
"$PREFIX_DIR/bin/anland-probe" --help >/dev/null 2>&1 || true
file "$PREFIX_DIR/bin/anland-probe"
sha256sum \
    "$PREFIX_DIR/src/display_producer.c" \
    "$PREFIX_DIR/include/display_producer.h" \
    "$PREFIX_DIR/include/protocol.h" \
    "$PREFIX_DIR/bin/anland-probe" \
    > "$PREFIX_DIR/SHA256SUMS"

cat <<EOF

Anland producer transport 已准备：
  $PREFIX_DIR

运行协议/缓冲区探针：
  $PREFIX_DIR/bin/anland-probe /tmp/anland/display_daemon.sock 15

成功标准：
  1. 能读出 Android 屏幕 width/height/refresh
  2. 打开 Anland Termux Activity 后退出 fallback
  3. 能列出 consumer 提供的 DMA-BUF fd/stride/size/modifier
  4. Android 鼠标/键盘/触摸输入时持续收到 input event

这一步只验证 Anland 5.13 transport，不会替换系统 wlroots。
EOF
