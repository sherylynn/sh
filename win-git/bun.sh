#!/usr/bin/env zsh

# 确保 toolsinit.sh 已加载
# 在单文件执行的场景下，这行代码能确保脚本正常工作
source "$(dirname "$0")/toolsinit.sh"

# --- 配置 ---
# 您可以在这里更改希望安装的 Bun 版本
BUN_VERSION="1.1.18"

# --- 脚本主体 ---

echo "准备安装 Bun v${BUN_VERSION}..."

# 1. 自动检测平台和架构
PLATFORM_RAW=$(uname -s)
BUN_ARCH_RAW=$(arch)

case "$PLATFORM_RAW" in
  Linux) BUN_PLATFORM="linux" ;;
  Darwin) BUN_PLATFORM="darwin" ;;
  *)
    # 对于 Windows (msys/cygwin), 沿用 nodejs.sh 的逻辑
    if [[ "$(platform)" == "win" ]]; then
      BUN_PLATFORM="windows"
    else
      echo "❌ 不支持的平台: $PLATFORM_RAW"
      exit 1
    fi
    ;;
esac

case "$BUN_ARCH_RAW" in
  amd64) BUN_ARCH="x64" ;;
  aarch64) BUN_ARCH="aarch64" ;;
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

# 3. 下载和解压
# cache_downloader 和 cache_unpacker 是 toolsinit.sh 提供的标准函数
cache_downloader "$BUN_FILE_PACK" "$BUN_URL"
# Bun 的 zip 包解压后文件夹名与压缩包名一致
cache_unpacker "$BUN_FILE_PACK" "$BUN_FILE_NAME"

# 4. 安装到工具目录
INSTALL_DIR=$(install_path)
echo "正在安装到 $INSTALL_DIR/bun..."
rm -rf "$INSTALL_DIR/bun"
# Bun 的 zip 包里有一个同名目录，我们需要的是那个目录
mv "$(cache_folder)/${BUN_FILE_NAME}" "$INSTALL_DIR/bun"

# 5. 配置环境变量 (使用标准 toolsRC 机制)
echo "正在配置环境变量..."
TOOLSRC_FILE=$(toolsRC "bunrc")

# 使用 cat 和 HEREDOC 写入配置
cat > "$TOOLSRC_FILE" <<EOF
# Bun environment variables
# This file is managed by toolsRC. Do not edit manually.

# 设置 Bun 的安装根目录
export BUN_INSTALL="\$HOME/tools/bun"

# 将 Bun 的可执行文件路径添加到 PATH
export PATH="\$BUN_INSTALL:\$PATH"
EOF

echo ""
echo "✅ Bun v${BUN_VERSION} 安装并配置完成！"
echo "请重启您的终端或运行 'source ~/.zshrc' (或等效命令) 来使配置生效。"
