#!/bin/bash
# 构建 wayvnc -> Anland 的 RFB SetDesktopSize 转发适配层。
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SOURCE="$SCRIPT_DIR/wayvnc_anland_resize.c"
OUTPUT=/root/.local/lib/wayvnc_anland_resize.so

command -v cc >/dev/null 2>&1 || {
    echo "缺少 C 编译器，请先安装 build-essential" >&2
    exit 1
}
install -d -m 0755 "$(dirname "$OUTPUT")"
cc -shared -fPIC -O2 -Wall -Wextra -Werror \
    -o "$OUTPUT.new" "$SOURCE" -ldl
chmod 0755 "$OUTPUT.new"
mv -f "$OUTPUT.new" "$OUTPUT"
echo "wayvnc Anland resize hook 已安装：$OUTPUT"
