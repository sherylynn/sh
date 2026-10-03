#!/bin/bash
set -Eeuo pipefail
task_repo=${NEWHOME_REPO:-/root/newhome}
task_installer="$task_repo/linux/scripts/install-rust-adb-default.sh"
[[ -f "$task_installer" ]] || {
    echo "缺少 NewHome Rust ADB 部署脚本：$task_installer" >&2
    exit 1
}
exec bash "$task_installer" "$@"
