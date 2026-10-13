#!/usr/bin/env bash
# NewHome Rust ADB 统一部署入口：安装平台二进制，并通过 toolsRC 持久化默认 adb。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=toolsinit.sh
. "$SCRIPT_DIR/toolsinit.sh"
set -Eeuo pipefail

platform_name="$(platform)"
case "$platform_name" in
  macos)
    task_repo=${NEWHOME_REPO:-$HOME/newhome}
    task_installer="$task_repo/mac/Scripts/install-rust-adb-default.sh"
    ;;
  *)
    task_repo=${NEWHOME_REPO:-/root/newhome}
    task_installer="$task_repo/linux/scripts/install-rust-adb-default.sh"
    ;;
esac

[[ -f "$task_installer" ]] || {
    echo "缺少 NewHome Rust ADB 部署脚本：$task_installer" >&2
    exit 1
}

bash "$task_installer" "$@"

toolsrc="$(toolsRC "newhomeadbrc")"
cat >"$toolsrc" <<'EOF'
# NewHome Rust ADB environment
# This file is managed by toolsRC. Do not edit manually.
NEWHOME_ADB_BIN="$HOME/tools/bin"
case ":$PATH:" in
  *":$NEWHOME_ADB_BIN:"*) PATH=":${PATH}:"; PATH="${PATH//:$NEWHOME_ADB_BIN:/:}"; PATH="${PATH#:}"; PATH="${PATH%:}" ;;
esac
export PATH="$NEWHOME_ADB_BIN:$PATH"
export NEWHOME_ADB="$NEWHOME_ADB_BIN/newhome-adb"
# 官方 adb 仅作为显式救援入口，不参与默认 adb 解析。
if [[ -x /opt/homebrew/bin/adb ]]; then
  export ANDROID_ADB_FALLBACK=/opt/homebrew/bin/adb
elif [[ -n "${ANDROID_HOME:-}" && -x "$ANDROID_HOME/platform-tools/adb" ]]; then
  export ANDROID_ADB_FALLBACK="$ANDROID_HOME/platform-tools/adb"
fi
EOF

# toolsRC按首次注册顺序source；确保NewHome ADB rc永远位于allToolsrc末尾，
# 防止Homebrew/Android SDK后续再次抢占adb。
source_line="test -f $toolsrc && . $toolsrc"
if [[ "$(tail -n 1 "$(alltoolsrc_file)" 2>/dev/null || true)" != "$source_line" ]]; then
  if [[ "$platform_name" == macos ]]; then
    sed -i "" "\|$toolsrc|d" "$(alltoolsrc_file)"
  else
    sed -i "\|$toolsrc|d" "$(alltoolsrc_file)"
  fi
  printf '%s\n' "$source_line" >>"$(alltoolsrc_file)"
fi

. "$toolsrc"
command -v adb
adb version | grep -q 'NewHome Rust ADB'
echo "NewHome Rust ADB 已写入 $toolsrc；后续 source ~/tools/rc/allToolsrc 后默认 adb 即 Rust ADB。"
