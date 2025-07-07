#!/data/data/com.termux/files/usr/bin/bash

# Termux 快捷方式生成脚本
# 生成 ~/.shortcuts/ 目录下的快捷方式脚本

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
SHORTCUTS_DIR="$HOME/.shortcuts"

# 确保快捷方式目录存在
mkdir -p "$SHORTCUTS_DIR"

echo "🔧 创建 Termux 快捷方式..."

# 1. 创建 tstart.sh - 启动所有服务
cat > "$SHORTCUTS_DIR/tstart.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Termux 一键启动所有服务 (持续运行版本)

# 设置脚本路径
SCRIPT_DIR="$HOME/sh/termux/chroot"

# 检查脚本是否存在
if [ ! -f "$SCRIPT_DIR/termux_all_in_one.sh" ]; then
    echo "❌ 脚本不存在: $SCRIPT_DIR/termux_all_in_one.sh"
    echo "请先运行: bash ~/sh/termux/chroot/setup_aliases.sh"
    exit 1
fi

# 启动所有服务
echo "🚀 启动 Termux 完整环境..."
bash "$SCRIPT_DIR/termux_all_in_one.sh" start

# 保持脚本运行 - 监控 termux-x11 进程
echo "📱 服务已启动，正在监控 termux-x11 进程..."
echo "💡 按 Ctrl+C 停止监控"

# 持续监控 termux-x11 进程
while true; do
    if ! pgrep -f "termux-x11" >/dev/null; then
        echo "⚠️  termux-x11 进程已停止，正在重启..."
        bash "$SCRIPT_DIR/termux_all_in_one.sh" start
        sleep 5
    fi
    sleep 10
done
EOF

# 2. 创建 tstop.sh - 停止所有服务
cat > "$SHORTCUTS_DIR/tstop.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Termux 一键停止所有服务

# 设置脚本路径
SCRIPT_DIR="$HOME/sh/termux/chroot"

# 检查脚本是否存在
if [ ! -f "$SCRIPT_DIR/termux_all_in_one.sh" ]; then
    echo "❌ 脚本不存在: $SCRIPT_DIR/termux_all_in_one.sh"
    echo "请先运行: bash ~/sh/termux/chroot/setup_aliases.sh"
    exit 1
fi

# 停止所有服务
echo "🛑 停止 Termux 完整环境..."
bash "$SCRIPT_DIR/termux_all_in_one.sh" stop

# 显示状态
echo ""
echo "📊 当前状态:"
bash "$SCRIPT_DIR/termux_all_in_one.sh" status
EOF

# 3. 创建 cstart.sh - 启动 chroot 容器
cat > "$SHORTCUTS_DIR/cstart.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# 启动 chroot Linux 容器 (持续运行版本)

# 设置脚本路径
SCRIPT_DIR="$HOME/sh/termux/chroot"

# 检查脚本是否存在
if [ ! -f "$SCRIPT_DIR/cli.sh" ]; then
    echo "❌ 脚本不存在: $SCRIPT_DIR/cli.sh"
    echo "请先运行: bash ~/sh/termux/chroot/setup_aliases.sh"
    exit 1
fi

# 启动 chroot 容器
echo "🐧 启动 chroot Linux 容器..."
bash "$SCRIPT_DIR/cli.sh" start

# 保持脚本运行 - 监控 chroot 挂载状态
echo "🐧 容器已启动，正在监控挂载状态..."
echo "💡 按 Ctrl+C 停止监控"

# 持续监控 chroot 挂载状态
while true; do
    if ! mount | grep -q "/data/local/mnt"; then
        echo "⚠️  chroot 容器已卸载，正在重启..."
        bash "$SCRIPT_DIR/cli.sh" start
        sleep 5
    fi
    sleep 10
done
EOF

# 4. 创建 cstop.sh - 停止 chroot 容器
cat > "$SHORTCUTS_DIR/cstop.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# 停止 chroot Linux 容器

# 设置脚本路径
SCRIPT_DIR="$HOME/sh/termux/chroot"

# 检查脚本是否存在
if [ ! -f "$SCRIPT_DIR/cli.sh" ]; then
    echo "❌ 脚本不存在: $SCRIPT_DIR/cli.sh"
    echo "请先运行: bash ~/sh/termux/chroot/setup_aliases.sh"
    exit 1
fi

# 停止 chroot 容器
echo "🛑 停止 chroot Linux 容器..."
bash "$SCRIPT_DIR/cli.sh" stop

# 显示状态
echo ""
echo "📊 容器状态:"
bash "$SCRIPT_DIR/cli.sh" status
EOF

# 5. 创建 cshell.sh - 进入 chroot shell
cat > "$SHORTCUTS_DIR/cshell.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# 进入 chroot Linux shell

# 设置脚本路径
SCRIPT_DIR="$HOME/sh/termux/chroot"

# 检查脚本是否存在
if [ ! -f "$SCRIPT_DIR/cli.sh" ]; then
    echo "❌ 脚本不存在: $SCRIPT_DIR/cli.sh"
    echo "请先运行: bash ~/sh/termux/chroot/setup_aliases.sh"
    exit 1
fi

# 检查容器是否运行
if ! bash "$SCRIPT_DIR/cli.sh" status >/dev/null 2>&1; then
    echo "⚠️  容器未运行，正在启动..."
    bash "$SCRIPT_DIR/cli.sh" start
fi

# 进入 chroot shell
echo "🐧 进入 chroot Linux 环境..."
bash "$SCRIPT_DIR/cli.sh" shell
EOF

# 6. 创建 tstatus.sh - 查看所有状态
cat > "$SHORTCUTS_DIR/tstatus.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# 查看 Termux 完整环境状态

# 设置脚本路径
SCRIPT_DIR="$HOME/sh/termux/chroot"

# 检查脚本是否存在
if [ ! -f "$SCRIPT_DIR/termux_all_in_one.sh" ]; then
    echo "❌ 脚本不存在: $SCRIPT_DIR/termux_all_in_one.sh"
    echo "请先运行: bash ~/sh/termux/chroot/setup_aliases.sh"
    exit 1
fi

# 显示完整状态
echo "📊 Termux 完整环境状态:"
bash "$SCRIPT_DIR/termux_all_in_one.sh" status
EOF

# 7. 创建 debug.sh - 进程搜索性能调试
cat > "$SHORTCUTS_DIR/debug.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# 进程搜索性能调试工具

# 设置脚本路径
SCRIPT_DIR="$HOME/sh/termux/chroot"

# 检查脚本是否存在
if [ ! -f "$SCRIPT_DIR/debug_process_search.sh" ]; then
    echo "❌ 调试脚本不存在: $SCRIPT_DIR/debug_process_search.sh"
    echo "请先运行: bash ~/sh/termux/chroot/setup_aliases.sh"
    exit 1
fi

# 运行调试工具
echo "🔍 启动进程搜索性能调试..."
bash "$SCRIPT_DIR/debug_process_search.sh"
EOF

# 设置执行权限
chmod +x "$SHORTCUTS_DIR"/*.sh

echo "✅ 快捷方式创建完成！"
echo ""
echo "📁 快捷方式位置: $SHORTCUTS_DIR"
echo ""
echo "🔧 可用的快捷方式:"
echo "  📱 tstart.sh         - 启动所有服务 (持续监控)"
echo "  📱 tstart_screen.sh  - 启动所有服务 (screen)"
echo "  🛑 tstop.sh          - 停止所有服务"
echo "  🐧 cstart.sh         - 启动 chroot 容器 (持续监控)"
echo "  🐧 cstart_screen.sh  - 启动 chroot 容器 (screen)"
echo "  🛑 cstop.sh          - 停止 chroot 容器"
echo "  💻 cshell.sh         - 进入 chroot shell"
echo "  📊 tstatus.sh        - 查看所有状态"
echo "  🔍 debug.sh          - 进程搜索性能调试"
echo ""
echo "💡 使用方法:"
echo "  1. 在 Termux 中运行: bash ~/sh/termux/chroot/create_shortcuts.sh"
echo "  2. 在 Android 桌面创建快捷方式，指向 ~/.shortcuts/ 目录下的脚本"
echo "  3. 或者直接在 Termux 中运行: bash ~/.shortcuts/tstart.sh"

# 创建使用 screen 的启动脚本 (更可靠的方案)
cat > "$SHORTCUTS_DIR/tstart_screen.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# 使用 screen 启动 Termux 服务 (推荐方案)

# 设置脚本路径
SCRIPT_DIR="$HOME/sh/termux/chroot"

# 检查脚本是否存在
if [ ! -f "$SCRIPT_DIR/termux_all_in_one.sh" ]; then
    echo "❌ 脚本不存在: $SCRIPT_DIR/termux_all_in_one.sh"
    echo "请先运行: bash ~/sh/termux/chroot/setup_aliases.sh"
    exit 1
fi

# 检查 screen 是否可用
if ! command -v screen >/dev/null 2>&1; then
    echo "⚠️  screen 不可用，使用 nohup 方案..."
    nohup bash "$SCRIPT_DIR/termux_all_in_one.sh" start > /dev/null 2>&1 &
    sleep 3
    bash "$SCRIPT_DIR/termux_all_in_one.sh" status
    exit 0
fi

# 使用 screen 启动服务
echo "🚀 使用 screen 启动 Termux 完整环境..."
exec screen -dmS termux_services bash -c "cd $SCRIPT_DIR && bash termux_all_in_one.sh start; exec bash"
EOF

# 创建使用 screen 的 chroot 启动脚本
cat > "$SHORTCUTS_DIR/cstart_screen.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# 使用 screen 启动 chroot 容器 (推荐方案)

# 设置脚本路径
SCRIPT_DIR="$HOME/sh/termux/chroot"

# 检查脚本是否存在
if [ ! -f "$SCRIPT_DIR/cli.sh" ]; then
    echo "❌ 脚本不存在: $SCRIPT_DIR/cli.sh"
    echo "请先运行: bash ~/sh/termux/chroot/setup_aliases.sh"
    exit 1
fi

# 检查 screen 是否可用
if ! command -v screen >/dev/null 2>&1; then
    echo "⚠️  screen 不可用，使用 nohup 方案..."
    nohup bash "$SCRIPT_DIR/cli.sh" start > /dev/null 2>&1 &
    sleep 3
    bash "$SCRIPT_DIR/cli.sh" status
    exit 0
fi

# 使用 screen 启动容器
echo "🐧 使用 screen 启动 chroot Linux 容器..."
exec screen -dmS chroot_container bash -c "cd $SCRIPT_DIR && bash cli.sh start; exec bash"
EOF

# 设置新脚本的执行权限
chmod +x "$SHORTCUTS_DIR"/tstart_screen.sh
chmod +x "$SHORTCUTS_DIR"/cstart_screen.sh

# 创建简单的持续运行版本 (解决快捷方式退出问题)
cat > "$SHORTCUTS_DIR/tstart_simple.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# 简单持续运行版本 - 解决快捷方式退出问题

SCRIPT_DIR="$HOME/sh/termux/chroot"

# 启动服务
echo "🚀 启动 Termux 环境..."
bash "$SCRIPT_DIR/termux_all_in_one.sh" start

# 保持运行 - 使用 termux-x11 作为持续进程
echo "📱 保持运行中..."
exec termux-x11 :1 -ac +extension DPMS
EOF

cat > "$SHORTCUTS_DIR/cstart_simple.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# 简单持续运行版本 - 解决快捷方式退出问题

SCRIPT_DIR="$HOME/sh/termux/chroot"

# 启动 chroot
echo "🐧 启动 chroot 容器..."
bash "$SCRIPT_DIR/cli.sh" start

# 保持运行 - 进入 chroot shell
echo "🐧 进入 chroot 环境..."
exec bash "$SCRIPT_DIR/cli.sh" shell
EOF

chmod +x "$SHORTCUTS_DIR"/tstart_simple.sh
chmod +x "$SHORTCUTS_DIR"/cstart_simple.sh

echo ""
echo "🎯 新增简单版本 (解决快捷方式退出问题):"
echo "  📱 tstart_simple.sh   - 启动所有服务 (简单持续运行)"
echo "  🐧 cstart_simple.sh   - 启动 chroot (简单持续运行)"
echo ""
echo "💡 推荐使用简单版本，它们会持续运行不会退出！" 