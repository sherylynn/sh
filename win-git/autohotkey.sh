#!/usr/bin/env zsh

# 确保 toolsinit.sh 已加载
source "$(dirname "$0")/toolsinit.sh"

# --- 配置 ---
# 您可以在这里更改希望安装的 AutoHotkey 版本
AHK_VERSION="1.1.36.02"

# --- 脚本主体 ---

echo "准备安装 AutoHotkey v${AHK_VERSION}..."

# 1. 自动检测平台和架构
PLATFORM=$(platform) # win, linux, macos
ARCH=$(arch)         # amd64, aarch64, armhf, etc.

# AutoHotkey 仅支持 Windows 平台安装
if [[ "$PLATFORM" != "win" ]]; then
    echo "⚠️  AutoHotkey 仅支持 Windows 平台安装"
    echo "当前检测到的平台: $PLATFORM"
    echo "将仅下载安装程序，不进行安装"
    DOWNLOAD_ONLY=true
else
    DOWNLOAD_ONLY=false
fi

# AutoHotkey v1 安装程序命名格式
if [[ "$PLATFORM" == "win" ]]; then
    echo "平台: Windows, 使用 v1 安装程序"
else
    echo "平台: $PLATFORM (下载模式), 使用 v1 安装程序"
fi

# 2. 构造文件名和下载链接
# AutoHotkey v1 安装程序命名格式
AHK_FILE_NAME="AutoHotkey_${AHK_VERSION}_setup.exe"
AHK_URL="https://github.com/AutoHotkey/AutoHotkey/releases/download/v${AHK_VERSION}/${AHK_FILE_NAME}"

echo "下载文件: $AHK_FILE_NAME"

# 3. 下载安装程序
cache_downloader "$AHK_FILE_NAME" "$AHK_URL"

# 4. 安装到工具目录 (仅 Windows 平台)
if [[ "$DOWNLOAD_ONLY" == "false" ]]; then
    INSTALL_DIR=$(install_path)
    AHK_INSTALL_PATH="$INSTALL_DIR/autohotkey"
    echo "正在安装 AutoHotkey 到 $AHK_INSTALL_PATH..."

    # 创建安装目录
    mkdir -p "$AHK_INSTALL_PATH"

    # 静默安装 AutoHotkey
    # /S 参数表示静默安装，/D= 指定安装目录
    # 注意：Windows 路径格式转换
    INSTALL_DIR_WIN=$(echo "$AHK_INSTALL_PATH" | sed 's/\//\\/g')
    echo "正在静默安装..."
    "$(cache_folder)/$AHK_FILE_NAME" /S /D="$INSTALL_DIR_WIN"

    # 5. 配置环境变量 (使用标准 toolsRC 机制)
    echo "正在配置环境变量..."
    TOOLSRC_FILE=$(toolsRC "autohotkeyrc")

    cat > "$TOOLSRC_FILE" <<EOF
# AutoHotkey environment variables
# This file is managed by toolsRC. Do not edit manually.

export AUTOHOTKEY_HOME=\$HOME/tools/autohotkey
export PATH="\$AUTOHOTKEY_HOME:\$PATH"
EOF

    echo ""
    echo "✅ AutoHotkey v${AHK_VERSION} 安装并配置完成！"
    echo "请重启您的终端或运行 'source ~/.zshrc' 来使配置生效。"
    echo "您可以通过运行 'AutoHotkey.exe /?' 来验证安装。"
    echo ""
    echo "使用说明："
    echo "  - 运行脚本: AutoHotkey.exe script.ahk"
    echo "  - 编译脚本: Ahk2Exe.exe /in script.ahk"
    echo "  - 帮助信息: AutoHotkey.exe /?"
echo ""
echo "注意: 这是 AutoHotkey v1 版本，语法与 v2 不同"
else
    echo ""
    echo "✅ AutoHotkey v${AHK_VERSION} 安装程序下载完成！"
    echo "文件位置: $(cache_folder)/$AHK_FILE_NAME"
    echo ""
    echo "由于当前不是 Windows 平台，仅下载了安装程序。"
    echo "您可以将此文件复制到 Windows 系统中运行安装。"
    echo ""
    echo "安装说明："
    echo "  - 在 Windows 中双击运行安装程序"
    echo "  - 或使用命令行: AutoHotkey_${AHK_VERSION}_setup.exe /S"
fi