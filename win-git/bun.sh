#!/usr/bin/env zsh

# 确保 toolsinit.sh 已加载
source "$(dirname "$0")/toolsinit.sh"

# --- 配置 ---
BUN_VERSION="1.1.18" # 您可以在这里更改希望安装的 Bun 版本

# 定义 Bun 的安装目录
BUN_HOME=$(install_path)/bun
TOOLSRC_NAME=bunrc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})

echo "准备安装 Bun v${BUN_VERSION}..."

# 1. 自动检测平台和架构
PLATFORM_RAW=$(uname -s)
BUN_ARCH_RAW=$(arch) # 使用 arch 获取更精确的架构

BUN_PLATFORM=""
BUN_ARCH=""

case "$PLATFORM_RAW" in
  Linux) BUN_PLATFORM="linux" ;;
  Darwin) BUN_PLATFORM="darwin" ;;
  *)
    # 对于 Windows (msys/cygwin), 沿用 platform 函数的逻辑
    if [[ "$(platform)" == "win" ]]; then
      BUN_PLATFORM="windows"
    else
      echo "❌ 不支持的平台: $PLATFORM_RAW"
      exit 1
    fi
    ;;
esac

case "$BUN_ARCH_RAW" in
  amd64|x86_64) BUN_ARCH="x64" ;; # macOS/Linux Intel
  aarch64|arm64) BUN_ARCH="aarch64" ;; # Linux/macOS ARM
  *)
    echo "❌ 不支持的架构: $BUN_ARCH_RAW"
    exit 1
    ;;
esac

# 2. 构造文件名和下载链接 (Bun 统一使用 .zip)
BUN_FILE_NAME="bun-${BUN_PLATFORM}-${BUN_ARCH}"
BUN_FILE_PACK="${BUN_FILE_NAME}.zip"
BUN_URL="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/${BUN_FILE_PACK}"

echo "平台: $BUN_PLATFORM, 架构: $BUN_ARCH"
echo "下载文件: $BUN_FILE_PACK"

# 3. 检查是否已安装指定版本的 Bun
# 注意: bun --version 可能会输出版本信息和一些警告，这里只检查版本号部分
if bun --version 2>/dev/null | grep -q "v${BUN_VERSION}"; then
  echo "✅ Bun v${BUN_VERSION} 已安装，跳过下载和解压。"
else
  # 下载和解压
  # cache_downloader 和 cache_unpacker 是 toolsinit.sh 提供的标准函数
  cache_downloader "$BUN_FILE_PACK" "$BUN_URL"
  # Bun 的 zip 包解压后文件夹名与压缩包名一致
  cache_unpacker "$BUN_FILE_PACK" "$BUN_FILE_NAME"

  # 安装到工具目录
  echo "正在安装到 $BUN_HOME..."
  rm -rf "$BUN_HOME" # 清理旧安装
  # Bun 的 zip 包里有一个同名目录，我们需要的是那个目录
  mv "$(cache_folder)/${BUN_FILE_NAME}" "$BUN_HOME"
fi

# 4. 配置环境变量 (使用标准 toolsRC 机制)
echo "正在配置环境变量..."

# 清空旧的 bunrc 配置
> "$TOOLSRC"

cat >> "$TOOLSRC" <<EOF
# Bun environment variables
# This file is managed by toolsRC. Do not edit manually.

# 设置 Bun 的安装根目录，Bun 可执行文件直接位于此目录下
export BUN_INSTALL="${BUN_HOME}"

# 将 Bun 的可执行文件路径添加到 PATH
export PATH="\$BUN_INSTALL:\$PATH"
EOF

echo ""
echo "✅ Bun v${BUN_VERSION} 安装并配置完成！"
echo "请重启您的终端或运行 'source ~/.zshrc' (或等效命令) 来使配置生效。"
