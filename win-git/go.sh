#!/usr/bin/env zsh

# 确保 toolsinit.sh 已加载
source "$(dirname "$0")/toolsinit.sh"

# --- 配置 ---
# 您可以在这里更改希望安装的 Go 版本
GO_VERSION="1.24.5"
# 国内用户可以考虑使用: https://golang.google.cn/dl/
GO_DOWNLOAD_HOST="https://go.dev/dl"

# --- 脚本主体 ---

echo "准备安装 Go v${GO_VERSION}..."

# 1. 自动检测平台和架构
PLATFORM=$(platform) # win, linux, macos
ARCH=$(arch)         # amd64, aarch64, armhf, etc.

# 适配 Go 的架构命名
case "$ARCH" in
  armhf) GO_ARCH="armv6l" ;;
  aarch64) GO_ARCH="arm64" ;;
  *) GO_ARCH=$ARCH ;;
esac

# 适配 Go 的平台命名
case "$PLATFORM" in
  win) GO_PLATFORM="windows" ;;
  wslinux) GO_PLATFORM="linux" ;;
  *) GO_PLATFORM=$PLATFORM ;;
esac

echo "平台: $GO_PLATFORM, 架构: $GO_ARCH"

# 2. 构造文件名和下载链接
if [[ "$GO_PLATFORM" == "windows" ]]; then
  PACK_EXT="zip"
else
  PACK_EXT="tar.gz"
fi

SOFT_FILE_NAME="go${GO_VERSION}.${GO_PLATFORM}-${GO_ARCH}"
SOFT_FILE_PACK="${SOFT_FILE_NAME}.${PACK_EXT}"
SOFT_URL="${GO_DOWNLOAD_HOST}/${SOFT_FILE_PACK}"

# 3. 下载和解压
cache_downloader "$SOFT_FILE_PACK" "$SOFT_URL"
# Go 的压缩包解压后文件夹名是 go
cache_unpacker "$SOFT_FILE_PACK" "go"

# 4. 安装到工具目录
INSTALL_DIR=$(install_path)
GO_ROOT_DIR="$INSTALL_DIR/goroot"
echo "正在安装到 $GO_ROOT_DIR..."
rm -rf "$GO_ROOT_DIR"
mv "$(cache_folder)/go" "$GO_ROOT_DIR"

# 5. 配置环境变量 (使用标准 toolsRC 机制)
echo "正在配置环境变量..."
TOOLSRC_FILE=$(toolsRC "golangrc")
GO_PATH_DIR="$INSTALL_DIR/gopath"
mkdir -p "$GO_PATH_DIR/bin"

# 国内用户推荐的 GOPROXY
GO_PROXY="https://goproxy.cn,direct"

cat > "$TOOLSRC_FILE" <<EOF
# Go environment variables
# This file is managed by toolsRC. Do not edit manually.

export GOROOT=\$HOME/tools/goroot
export GOPATH=\$HOME/tools/gopath
export GO111MODULE=on
export GOPROXY=${GO_PROXY}

export PATH=\$GOROOT/bin:\$GOPATH/bin:\$PATH
EOF

echo ""
echo "✅ Go v${GO_VERSION} 安装并配置完成！"
echo "请重启您的终端或运行 'source ~/.zshrc' 来使配置生效。"
echo "您可以通过运行 'go version' 来验证安装。"

