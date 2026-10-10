#!/usr/bin/env bash

# Flutter 官方 SDK 安装/升级工具。
# - 只跟踪官方 stable channel，不硬编码具体版本号。
# - SDK 统一安装到 ~/tools/flutter。
# - 环境变量统一通过 toolsRC/allToolsrc 管理，不再修改 ~/.bash_profile。
# - 使用 CFUG Pub/Storage 镜像加速 ARM64 工具链；Git 镜像可通过 FLUTTER_GIT_MIRROR 指定。

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=toolsinit.sh
. "$SCRIPT_DIR/toolsinit.sh"

# toolsinit.sh 兼容大量历史环境，不按 nounset 编写；加载完成后再启用严格模式。
set -euo pipefail

INSTALL_ROOT="$(install_path)"
FLUTTER_HOME="$INSTALL_ROOT/flutter"
TOOLSRC_NAME="flutterrc"
FLUTTER_REPO="https://github.com/flutter/flutter.git"
FLUTTER_GIT_MIRROR="${FLUTTER_GIT_MIRROR:-}"
FLUTTER_FETCH_REPO="${FLUTTER_GIT_MIRROR:-$FLUTTER_REPO}"
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
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
EOF

  # 当前脚本进程立即生效；后续 shell 由 allToolsrc 自动加载。
  export FLUTTER_HOME="$FLUTTER_HOME"
  export PATH="$FLUTTER_HOME/bin:$PATH"
  export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
  export PUB_HOSTED_URL="https://pub.flutter-io.cn"

  echo "Flutter 环境已写入：$toolsrc"
  echo "后续 shell 将通过 ~/tools/rc/allToolsrc 自动加载。"
}

install_or_update_flutter() {
  mkdir -p "$INSTALL_ROOT"

  if [ ! -e "$FLUTTER_HOME" ]; then
    echo "正在从 $FLUTTER_FETCH_REPO 安装 Flutter $FLUTTER_CHANNEL channel..."
    git -c http.version=HTTP/1.1 clone --depth 1 --no-tags --branch "$FLUTTER_CHANNEL" --single-branch "$FLUTTER_FETCH_REPO" "$FLUTTER_HOME"
    git -C "$FLUTTER_HOME" remote set-url origin "$FLUTTER_REPO"
    return
  fi

  if [ ! -d "$FLUTTER_HOME/.git" ]; then
    echo "错误：$FLUTTER_HOME 已存在，但不是 Flutter Git SDK。" >&2
    echo "请先备份或移走该目录后重试。" >&2
    exit 1
  fi

  # An interrupted first clone may leave only .git without a valid HEAD.
  # Resume it without discarding any existing worktree content.
  if ! git -C "$FLUTTER_HOME" rev-parse --verify HEAD >/dev/null 2>&1; then
    if [ -n "$(find "$FLUTTER_HOME" -mindepth 1 -maxdepth 1 ! -name .git -print -quit)" ]; then
      echo "错误：Flutter SDK 缺少 HEAD 且目录有其它文件，拒绝自动修复。" >&2
      exit 1
    fi
    echo "检测到中断的 Flutter 初次克隆，继续拉取 stable 浅历史..."
    git -C "$FLUTTER_HOME" config --unset-all remote.origin.promisor 2>/dev/null || true
    git -C "$FLUTTER_HOME" config --unset-all remote.origin.partialclonefilter 2>/dev/null || true
    git -c http.version=HTTP/1.1 -C "$FLUTTER_HOME" fetch --refetch --depth 1 --no-tags "$FLUTTER_FETCH_REPO" "$FLUTTER_CHANNEL"
    git -C "$FLUTTER_HOME" checkout -B "$FLUTTER_CHANNEL" FETCH_HEAD
    git -C "$FLUTTER_HOME" branch --set-upstream-to="origin/$FLUTTER_CHANNEL" "$FLUTTER_CHANNEL" 2>/dev/null || true
    return
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

  echo "正在从 $FLUTTER_FETCH_REPO 更新 Flutter $FLUTTER_CHANNEL channel..."
  git -c http.version=HTTP/1.1 -C "$FLUTTER_HOME" fetch --depth 1 --no-tags "$FLUTTER_FETCH_REPO" "$FLUTTER_CHANNEL"

  # checkout 后只允许 fast-forward，绝不 reset/覆盖用户本地提交。
  git -C "$FLUTTER_HOME" checkout "$FLUTTER_CHANNEL"
  # Shallow history may not include the previous stable HEAD; deepen safely.
  local attempt=0
  while ! git -C "$FLUTTER_HOME" merge-base --is-ancestor HEAD FETCH_HEAD; do
    if [ "$attempt" -ge 10 ]; then
      echo "错误：无法验证 stable 更新是 fast-forward，拒绝自动合并。" >&2
      exit 1
    fi
    git -c http.version=HTTP/1.1 -C "$FLUTTER_HOME" fetch --deepen 50 --no-tags "$FLUTTER_FETCH_REPO" "$FLUTTER_CHANNEL"
    attempt=$((attempt + 1))
  done
  git -C "$FLUTTER_HOME" merge --ff-only FETCH_HEAD
}

verify_mirror_commit() {
  if [ "$FLUTTER_FETCH_REPO" = "$FLUTTER_REPO" ]; then
    return
  fi
  local official_head installed_head
  official_head="$(git -c http.version=HTTP/1.1 ls-remote --heads "$FLUTTER_REPO" "$FLUTTER_CHANNEL" | cut -f1)"
  installed_head="$(git -C "$FLUTTER_HOME" rev-parse HEAD)"
  if [ -z "$official_head" ] || [ "$installed_head" != "$official_head" ]; then
    echo "错误：镜像提交与 Flutter 官方 stable HEAD 不一致，拒绝初始化。" >&2
    echo "官方：$official_head；本地：$installed_head" >&2
    exit 1
  fi
  echo "已核对 Flutter 镜像提交与官方 stable HEAD 一致：$installed_head"
}

ensure_version_tag() {
  # Shallow clones omit tags, which makes Flutter report 0.0.0-unknown.
  if git -C "$FLUTTER_HOME" describe --tags --exact-match HEAD >/dev/null 2>&1; then
    return
  fi
  local head tag
  head="$(git -C "$FLUTTER_HOME" rev-parse HEAD)"
  tag="$(git ls-remote --tags "$FLUTTER_FETCH_REPO" | grep "^$head[[:space:]]" | grep -E "refs/tags/[0-9]" | cut -f2 | sed "s#refs/tags/##" | sort -V | tail -1 || true)"
  if [ -n "$tag" ]; then
    git -c http.version=HTTP/1.1 -C "$FLUTTER_HOME" fetch --depth 1 --no-tags "$FLUTTER_FETCH_REPO" "refs/tags/$tag:refs/tags/$tag"
  else
    echo "警告：当前 Flutter stable HEAD 尚无版本 tag，Flutter 可能显示 unknown。" >&2
  fi
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
  verify_mirror_commit
  ensure_version_tag
  configure_toolsrc
  verify_flutter
}

main "$@"
