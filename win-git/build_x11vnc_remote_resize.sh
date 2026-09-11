#!/bin/bash
set -Eeuo pipefail

SOURCE=${RESIZE_SOURCE:-"${BASH_SOURCE%/*}/x11vnc_remote_resize.c"}
LIBRARY=${RESIZE_LIBRARY:-"$HOME/.local/lib/x11vnc_remote_resize.so"}
BUILD=""

cleanup() {
    [ -z "$BUILD" ] || rm -f "$BUILD"
}
trap cleanup EXIT

if [ ! -f "$SOURCE" ]; then
    echo "缺少 noVNC 远程分辨率适配源码：$SOURCE" >&2
    exit 1
fi

mkdir -p "$(dirname "$LIBRARY")"
BUILD=$(mktemp "${LIBRARY}.new.XXXXXX")
gcc -shared -fPIC -O2 -Wall -Wextra -Werror \
    -o "$BUILD" "$SOURCE" -ldl -pthread

for symbol in rfbGetScreen; do
    if ! readelf -Ws "$BUILD" | grep -q "[[:space:]]${symbol}$"; then
        echo "noVNC/x11vnc 适配库校验失败：未导出 ${symbol}" >&2
        exit 1
    fi
done
if ! strings "$BUILD" | grep -q 'flags=0x%08x dpi=%u mode=%s render='; then
    echo "noVNC 远程分辨率适配库校验失败：缺少 HiDPI/DPI 协议支持" >&2
    exit 1
fi

chmod 0755 "$BUILD"
mv -f "$BUILD" "$LIBRARY"
BUILD=""
echo "noVNC/x11vnc 远程分辨率、HiDPI 与 DPI/render 适配库已更新：$LIBRARY"
