#!/usr/bin/env zsh

# 确保 toolsinit.sh 已加载
# 在单文件执行的场景下，这行代码能确保脚本正常工作
source "$(dirname "$0")/toolsinit.sh"

# --- 配置 ---
# 您可以在这里更改希望安装的 Node.js 版本
NODE_VERSION="18.17.1" # 更新到了一个较新的 LTS 版本

# --- 脚本主体 ---

echo "准备安装 Node.js v${NODE_VERSION}..."

# 1. 自动检测平台和架构
PLATFORM=$(platform)
NODE_ARCH_RAW=$(arch)

case "$NODE_ARCH_RAW" in
  amd64) NODE_ARCH="x64" ;;
  aarch64) NODE_ARCH="arm64" ;;
  386) NODE_ARCH="x86" ;;
  *)
    echo "❌ 不支持的架构: $NODE_ARCH_RAW"
    exit 1
    ;;
esac

# 2. 构造文件名和下载链接
# 注意: Windows 是 .zip 包, Linux/macOS 是 .tar.gz 包
if [[ "$PLATFORM" == "win" ]]; then
  PACK_EXT="zip"
else
  # macOS 和 Linux 统一使用 linux
  PLATFORM="linux"
  PACK_EXT="tar.gz"
fi

NODE_FILE_NAME="node-v${NODE_VERSION}-${PLATFORM}-${NODE_ARCH}"
NODE_FILE_PACK="${NODE_FILE_NAME}.${PACK_EXT}"
# 使用淘宝镜像源以获得更好的下载速度
NODE_URL="https://npm.taobao.org/mirrors/node/v${NODE_VERSION}/${NODE_FILE_PACK}"

echo "平台: $PLATFORM, 架构: $NODE_ARCH"
echo "下载文件: $NODE_FILE_PACK"

# 3. 下载和解压
# cache_downloader 和 cache_unpacker 是 toolsinit.sh 提供的标准函数
cache_downloader "$NODE_FILE_PACK" "$NODE_URL"
cache_unpacker "$NODE_FILE_PACK" "$NODE_FILE_NAME"

# 4. 安装到工具目录
INSTALL_DIR=$(install_path)
echo "正在安装到 $INSTALL_DIR/node..."
rm -rf "$INSTALL_DIR/node"
mv "$(cache_folder)/${NODE_FILE_NAME}" "$INSTALL_DIR/node"

# 5. 配置环境变量 (使用标准 toolsRC 机制)
echo "正在配置环境变量..."
TOOLSRC_FILE=$(toolsRC "noderc")

# 创建全局包和缓存目录
mkdir -p "$INSTALL_DIR/node-global"
mkdir -p "$INSTALL_DIR/node-cache"

# 使用 cat 和 HEREDOC 写入配置，清晰且不易出错
cat > "$TOOLSRC_FILE" <<EOF
# Node.js environment variables
# This file is managed by toolsRC. Do not edit manually.

# 设置 npm 全局安装路径和缓存路径
export NPM_CONFIG_PREFIX=\$HOME/tools/node-global
export NPM_CONFIG_CACHE=\$HOME/tools/node-cache

# 将 Node.js 和全局 npm 包的可执行文件路径添加到 PATH
if [[ "\$(platform)" == "win" ]]; then
  # Windows: node.exe 在根目录
  export PATH="\$HOME/tools/node:\$HOME/tools/node-global:\$PATH"
else
  # Linux/macOS: node 在 bin 目录
  export PATH="\$HOME/tools/node/bin:\$HOME/tools/node-global/bin:\$PATH"
fi
EOF

echo ""
echo "✅ Node.js v${NODE_VERSION} 安装并配置完成！"
echo "请重启您的终端或运行 'source ~/.zshrc' 来使配置生效。"

