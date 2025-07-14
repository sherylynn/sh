#!/usr/bin/env zsh

# 确保 toolsinit.sh 已加载
# 在单文件执行的场景下，这行代码能确保脚本正常工作
source "$(dirname "$0")/toolsinit.sh"

# --- 配置 ---
# 您可以在这里更改希望安装的 Python 版本
PYTHON_VERSION="3.11.5"
PYTHON_BUILD_VERSION="20230826" # python-build-standalone 的发布日期

# --- 脚本主体 ---

echo "准备安装 Python v${PYTHON_VERSION}..."

# 1. 自动检测平台和架构
PLATFORM_RAW=$(platform) # win, linux, macos
ARCH_RAW=$(arch)         # amd64, aarch64

# 2. 根据平台和架构构造下载文件名和 URL
# 参考: https://github.com/indygreg/python-build-standalone/releases
case "$PLATFORM_RAW" in
  win)
    PY_PLATFORM="pc-windows-msvc-shared"
    PY_ARCH="x86_64"
    ;;
  linux)
    PY_PLATFORM="unknown-linux-gnu"
    PY_ARCH="x86_64"
    ;;
  macos)
    PY_PLATFORM="apple-darwin"
    if [[ "$ARCH_RAW" == "aarch64" ]]; then
      PY_ARCH="aarch64"
    else
      PY_ARCH="x86_64"
    fi
    ;;
  *)
    echo "❌ 不支持的平台: $PLATFORM_RAW"
    exit 1
    ;;
esac

PYTHON_FULL_VERSION="cpython-${PYTHON_VERSION}+${PYTHON_BUILD_VERSION}"
PYTHON_DIR_NAME="${PYTHON_FULL_VERSION}-${PY_ARCH}-${PY_PLATFORM}-install_only"
PYTHON_FILE_PACK="${PYTHON_DIR_NAME}.tar.gz"
PYTHON_URL="https://github.com/indygreg/python-build-standalone/releases/download/${PYTHON_BUILD_VERSION}/${PYTHON_FILE_PACK}"

echo "平台: $PLATFORM_RAW, 架构: $PY_ARCH"
echo "下载文件: $PYTHON_FILE_PACK"

# 3. 下载和解压
cache_downloader "$PYTHON_FILE_PACK" "$PYTHON_URL"
cache_unpacker "$PYTHON_FILE_PACK" "$PYTHON_DIR_NAME"

# 4. 安装到工具目录
INSTALL_DIR=$(install_path)
PYTHON_INSTALL_PATH="$INSTALL_DIR/python"
echo "正在安装到 $PYTHON_INSTALL_PATH..."
rm -rf "$PYTHON_INSTALL_PATH"
# 解压出来的目录是 python
mv "$(cache_folder)/${PYTHON_DIR_NAME}/python" "$PYTHON_INSTALL_PATH"

# 5. 配置环境变量 (使用标准 toolsRC 机制)
echo "正在配置环境变量..."
TOOLSRC_FILE=$(toolsRC "pythonrc")

PIP_USERBASE="$INSTALL_DIR/python-pip"
mkdir -p "$PIP_USERBASE"

# 使用 cat 和 HEREDOC 写入配置
cat > "$TOOLSRC_FILE" <<EOF
# Python environment variables
# This file is managed by toolsRC. Do not edit manually.

export PYTHON_HOME=\$HOME/tools/python
export PYTHONUSERBASE=\$HOME/tools/python-pip

# 根据平台设置不同的 PATH
if [[ "\$(platform)" == "win" ]]; then
  # Windows: python.exe 在根目录, Scripts 在 Scripts 目录
  export PATH="\$PYTHON_HOME:\$PYTHON_HOME/Scripts:\$PYTHONUSERBASE/Scripts:\$PATH"
else
  # Linux/macOS: python 在 bin 目录
  export PATH="\$PYTHON_HOME/bin:\$PYTHONUSERBASE/bin:\$PATH"
fi
EOF

echo ""
echo "✅ Python v${PYTHON_VERSION} 安装并配置完成！"
echo "请重启您的终端或运行 'source ~/.zshrc' 来使配置生效。"
echo "您可以通过运行 'python --version' 或 'pip --version' 来验证安装。"

