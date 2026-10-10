#!/usr/bin/env bash

# Flutter 官方 SDK 安装/升级工具。
# - 只跟踪官方 stable channel，不硬编码具体版本号。
# - SDK 统一安装到 ~/tools/flutter。
# - 环境变量统一通过 toolsRC/allToolsrc 管理，不再修改 ~/.bash_profile。
# - 不强制设置第三方 PUB/Storage 镜像，默认使用 Flutter 官方服务。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=toolsinit.sh
. "$SCRIPT_DIR/toolsinit.sh"

# toolsinit.sh 兼容大量历史环境，不按 nounset 编写；加载完成后再启用严格模式。
set -euo pipefail

INSTALL_ROOT="$(install_path)"
FLUTTER_HOME="$INSTALL_ROOT/flutter"
TOOLSRC_NAME="flutterrc"
FLUTTER_REPO="https://github.com/flutter/flutter.git"
FLUTTER_CHANNEL="stable"

ensure_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "错误：安装 Flutter 需要 git。" >&2
    exit 1
  fi
}

configure_toolsrc() {
  local toolsrc
  toolsrc="$(toolsRC "$TOOLSRC_NAME")"

  cat > "$toolsrc" <<'EOF'
# Flutter environment variables
# This file is managed by toolsRC. Do not edit manually.

export FLUTTER_HOME="$HOME/tools/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"
EOF

  # 当前脚本进程立即生效；后续 shell 由 allToolsrc 自动加载。
  export FLUTTER_HOME="$FLUTTER_HOME"
  export PATH="$FLUTTER_HOME/bin:$PATH"

  echo "Flutter 环境已写入：$toolsrc"
  echo "后续 shell 将通过 ~/tools/rc/allToolsrc 自动加载。"
}

install_or_update_flutter() {
  mkdir -p "$INSTALL_ROOT"

  if [ ! -e "$FLUTTER_HOME" ]; then
    echo "正在从 Flutter 官方仓库安装 $FLUTTER_CHANNEL channel..."
    git clone --branch "$FLUTTER_CHANNEL" --single-branch "$FLUTTER_REPO" "$FLUTTER_HOME"
    return
  fi

  if [ ! -d "$FLUTTER_HOME/.git" ]; then
    echo "错误：$FLUTTER_HOME 已存在，但不是 Flutter Git SDK。" >&2
    echo "请先备份或移走该目录后重试。" >&2
    exit 1
  fi

  if [ -n "$(git -C "$FLUTTER_HOME" status --porcelain)" ]; then
    echo "错误：Flutter SDK 工作树存在本地修改，为避免覆盖，拒绝自动升级：" >&2
    git -C "$FLUTTER_HOME" status --short >&2
    exit 1
  fi

  local remote_url
  remote_url="$(git -C "$FLUTTER_HOME" remote get-url origin 2>/dev/null || true)"
  if [ "$remote_url" != "$FLUTTER_REPO" ] &&
     [ "$remote_url" != "git@github.com:flutter/flutter.git" ]; then
    echo "错误：现有 Flutter SDK 的 origin 不是官方仓库：" >&2
    echo "  $remote_url" >&2
    exit 1
  fi

  echo "正在更新 Flutter 官方 $FLUTTER_CHANNEL channel..."
  git -C "$FLUTTER_HOME" fetch origin "$FLUTTER_CHANNEL" --tags --prune

  # checkout 后只允许 fast-forward，绝不 reset/覆盖用户本地提交。
  git -C "$FLUTTER_HOME" checkout "$FLUTTER_CHANNEL"
  git -C "$FLUTTER_HOME" merge --ff-only "origin/$FLUTTER_CHANNEL"
}

verify_flutter() {
  echo
  echo "Flutter SDK：$FLUTTER_HOME"
  flutter --version
  echo
  flutter doctor
}

main() {
  ensure_git
  install_or_update_flutter
  configure_toolsrc
  verify_flutter
}

main "$@"
