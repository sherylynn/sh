#!/usr/bin/env zsh

# 确保 toolsinit.sh 已加载
source "$(dirname "$0")/toolsinit.sh"

TOOLSRC_NAME=bunrc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/bun

# --- 配置 ---
SOFT_VERSION="1.1.18"

echo "准备安装 Bun v${SOFT_VERSION}..."

# 平台检测
PLATFORM=$(platform)
if [[ "$PLATFORM" == "macos" ]]; then
  SOFT_PLATFORM=darwin
elif [[ "$PLATFORM" == "wslinux" ]]; then
  SOFT_PLATFORM=linux
elif [[ "$PLATFORM" == "win" ]]; then
  SOFT_PLATFORM=windows
else
  SOFT_PLATFORM=$PLATFORM
fi

# 架构检测
case $(arch) in
  amd64) SOFT_ARCH=x64 ;;
  aarch64) SOFT_ARCH=aarch64 ;;
esac

# Alpine Linux 使用 musl 版本
if [[ -f /etc/alpine-release ]] && [[ "$SOFT_PLATFORM" == "linux" ]]; then
  SOFT_ARCH="${SOFT_ARCH}-musl"
fi

SOFT_FILE_NAME="bun-${SOFT_PLATFORM}-${SOFT_ARCH}"
SOFT_FILE_PACK="${SOFT_FILE_NAME}.zip"
SOFT_URL="https://github.com/oven-sh/bun/releases/download/bun-v${SOFT_VERSION}/${SOFT_FILE_PACK}"

# Windows 可执行文件名
BUN_EXE="bun"
if [[ "$PLATFORM" == "win" ]]; then
  BUN_EXE="bun.exe"
fi

# 下载和安装
if ! bun --version 2>/dev/null | grep -q "${SOFT_VERSION}"; then
  cache_downloader "$SOFT_FILE_PACK" "$SOFT_URL"
  cache_unpacker "$SOFT_FILE_PACK" "$SOFT_FILE_NAME"

  rm -rf "$SOFT_HOME"
  mkdir -p "$SOFT_HOME"
  # Bun zip 包结构: bun-${PLATFORM}-${ARCH}/bun-${PLATFORM}-${ARCH}/bun
  mv "$(cache_folder)/${SOFT_FILE_NAME}/${SOFT_FILE_NAME}/${BUN_EXE}" "$SOFT_HOME/"
  rm -rf "$(cache_folder)/${SOFT_FILE_NAME}"
fi

# 配置环境变量
echo 'export BUN_INSTALL='$SOFT_HOME >${TOOLSRC}
echo 'export PATH=$BUN_INSTALL:$PATH' >>${TOOLSRC}

echo ""
echo "✅ Bun v${SOFT_VERSION} 安装并配置完成！"
echo "请重启您的终端或运行 'source ~/.zshrc' 来使配置生效。"