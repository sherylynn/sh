#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
NAME=termux_aliases
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})

# 设置脚本权限
setup_permissions() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local scripts=(
        "$script_dir/termux_all_in_one.sh"
        "$script_dir/cli.sh"
        "$script_dir/setup_aliases.sh"
        "$script_dir/mount_config_manager.sh"
    )
    
    echo "设置脚本执行权限..."
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            echo "设置权限: $script"
        fi
    done
}

# 配置别名
setup_permissions

tee ${TOOLSRC} <<-'EOF'
# === Termux 便捷别名 (通过toolsRC管理) ===

# Termux 一键启动管理
alias tstart='bash ~/sh/termux/chroot/termux_all_in_one.sh start'
alias tstop='bash ~/sh/termux/chroot/termux_all_in_one.sh stop'
alias trestart='bash ~/sh/termux/chroot/termux_all_in_one.sh restart'
alias tstatus='bash ~/sh/termux/chroot/termux_all_in_one.sh status'
alias tenter='bash ~/sh/termux/chroot/termux_all_in_one.sh enter'

# Chroot Linux 管理 (使用合并后的cli.sh)
alias cstart='bash ~/sh/termux/chroot/cli.sh start'
alias cstop='bash ~/sh/termux/chroot/cli.sh stop'
alias crestart='bash ~/sh/termux/chroot/cli.sh restart'
alias cstatus='bash ~/sh/termux/chroot/cli.sh status'
alias cshell='bash ~/sh/termux/chroot/cli.sh shell'
alias cexec='bash ~/sh/termux/chroot/cli.sh exec'

# 卸载相关 (智能卸载 vs 快速卸载)
alias cumount='bash ~/sh/termux/chroot/cli.sh umount'
alias cfastum='bash ~/sh/termux/chroot/cli.sh fast-umount'
alias cforce='bash ~/sh/termux/chroot/cli.sh force-cleanup'

# 卸载超时配置
alias ctimeout='bash ~/sh/termux/chroot/cli.sh set-timeout'

# X11 和图形界面
alias x11start='bash ~/sh/termux/server_x11.sh'
alias x11stop='sudo killall Xvfb'

# 挂载配置管理
alias mlist='bash ~/sh/termux/chroot/mount_config_manager.sh list'
alias medit='bash ~/sh/termux/chroot/mount_config_manager.sh edit'
alias mverify='bash ~/sh/termux/chroot/mount_config_manager.sh verify'
alias mstatus='bash ~/sh/termux/chroot/mount_config_manager.sh status'
alias mconfig='bash ~/sh/termux/chroot/mount_config_manager.sh'

# 常用工具别名
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias cls='clear'
alias ..='cd ..'
alias ...='cd ../..'

# 快速编辑重要配置
alias edit-aliases='nano ~/sh/termux/chroot/setup_aliases.sh'
alias reload-aliases='source ~/.zshrc'

# Android 开发相关
alias adb-reset='adb kill-server && adb start-server'
alias adb-devices='adb devices -l'

# 网络工具
alias myip='curl -s ifconfig.me'
alias ports='netstat -tuln'

# 进程管理
alias psg='ps aux | grep -v grep | grep'
alias topu='top -o %CPU'
alias topm='top -o %MEM'

# 文件操作
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias mkdir='mkdir -pv'

# 系统信息
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias path='echo -e ${PATH//:/\\n}'

# Git 快捷操作
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'

echo "✅ Termux 别名配置已加载！"
echo "📋 可用的主要命令:"
echo "   🔧 整体服务: tstart, tstop, tstatus"
echo "   🐧 Linux容器: cstart, cstop, cshell"  
echo "   ⚡ 快速卸载: cfastum, cumount, cforce"
echo "💡 运行 'alias | grep -E \"^(t|c|x11)\"' 查看所有 Termux 别名"
EOF

echo "🎉 别名配置完成！"
echo ""
echo "📌 配置文件位置: ${TOOLSRC}"
echo ""
echo "🔄 重新加载配置:"
echo "   source ~/.zshrc  # 或 source ~/.bashrc"
echo ""
echo "✨ 主要命令:"
echo "   tstart   - 启动所有服务"
echo "   tstop    - 停止所有服务"
echo "   tstatus  - 查看状态"
echo "   cshell   - 进入 Linux 环境"
echo ""
echo "⚡ 快速卸载命令:"
echo "   cumount  - 智能卸载 (倒计时可跳过)"
echo "   cfastum  - 快速强制卸载 (最快)"
echo "   cforce   - 应急清理 (失败时用)"
echo "   ctimeout - 设置卸载超时时间"
echo ""
echo "📋 查看所有别名:"
echo "   alias | grep -E '^(t|c|x11)'" 