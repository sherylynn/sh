#!/bin/bash
set -Eeuo pipefail
task_root=$(mktemp -d)
trap 'rm -rf "$task_root"' EXIT
script_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
repo=${NEWHOME_REPO:-/root/newhome}
mkdir -p "$task_root/usr/bin" "$task_root/usr/local/bin"
install -m755 "$repo/target/release/newhome-adb" "$task_root/usr/bin/newhome-adb"
install -m755 "$repo/target/release/newhome-adb-server" "$task_root/usr/bin/newhome-adb-server"
install -m755 /usr/lib/android-sdk/platform-tools/adb "$task_root/usr/local/bin/adb"
before=$(sha256sum "$task_root/usr/local/bin/adb" | cut -d' ' -f1)
NEWHOME_ADB_PREFIX="$task_root" bash "$script_dir/win-git/newhome_rust_adb_setup.sh"
"$task_root/usr/local/bin/adb" version | grep -q 'NewHome Rust ADB'
test "$(sha256sum "$task_root/usr/local/bin/adb.pre-newhome" | cut -d' ' -f1)" = "$before"
NEWHOME_ADB_PREFIX="$task_root" bash "$script_dir/win-git/newhome_rust_adb_setup.sh"
test "$(sha256sum "$task_root/usr/local/bin/adb.pre-newhome" | cut -d' ' -f1)" = "$before"
mv "$task_root/usr/bin/newhome-adb-server" "$task_root/usr/bin/newhome-adb-server.saved"
if NEWHOME_ADB_PREFIX="$task_root" bash "$script_dir/win-git/newhome_rust_adb_setup.sh"; then
    echo '缺少 server 时不应该报告部署成功' >&2
    exit 1
fi
"$task_root/usr/local/bin/adb" version | grep -q 'NewHome Rust ADB'
echo '默认 Rust ADB：安装、原入口备份、重复部署、缺少产物拒绝均通过'
