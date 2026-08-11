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
        "$script_dir/proot_all_in_one.sh"
        "$script_dir/proot_cli.sh"
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

# 创建快捷方式
# bash "$(dirname "${BASH_SOURCE[0]}")/create_shortcuts.sh" >/dev/null 2>&1 || {
#   echo "[WARN] 快捷方式脚本生成失败，可忽略。"
# }

tee ${TOOLSRC} <<-'EOF'
# === Termux 便捷别名 (通过toolsRC管理) ===
# 固定入口: t* / c* 走 chroot，p* 走 proot

# Termux 一键启动管理: 固定 chroot
alias tstart='bash ~/sh/termux/chroot/termux_all_in_one.sh start'
alias tstop='bash ~/sh/termux/chroot/termux_all_in_one.sh stop'
alias trestart='bash ~/sh/termux/chroot/termux_all_in_one.sh restart'
alias tstatus='bash ~/sh/termux/chroot/termux_all_in_one.sh status'
alias tenter='bash ~/sh/termux/chroot/termux_all_in_one.sh enter'
alias tinit='bash ~/sh/termux/chroot/termux_all_in_one.sh init'
alias tinstall='bash ~/sh/termux/chroot/termux_all_in_one.sh install'
# Chroot Linux 管理: 固定 chroot
alias cstart='bash ~/sh/termux/chroot/cli.sh start'
alias cstop='bash ~/sh/termux/chroot/cli.sh stop'
alias crestart='bash ~/sh/termux/chroot/cli.sh restart'
alias cstatus='bash ~/sh/termux/chroot/cli.sh status'
alias cshell='bash ~/sh/termux/chroot/cli.sh shell'
alias cexec='bash ~/sh/termux/chroot/cli.sh exec'
alias cforce='bash ~/sh/termux/chroot/cli.sh force-cleanup'

# ========== chroot 专属 (前缀 tchroot*) ==========
alias tchstart='bash ~/sh/termux/chroot/termux_all_in_one.sh start'
alias tchstop='bash ~/sh/termux/chroot/termux_all_in_one.sh stop'
alias tchrestart='bash ~/sh/termux/chroot/termux_all_in_one.sh restart'
alias tchstatus='bash ~/sh/termux/chroot/termux_all_in_one.sh status'
alias tchenter='bash ~/sh/termux/chroot/termux_all_in_one.sh enter'
alias tchinstall='bash ~/sh/termux/chroot/termux_all_in_one.sh install'

# chroot CLI (原始 cli.sh)
alias cchstart='bash ~/sh/termux/chroot/cli.sh start'
alias cchstop='bash ~/sh/termux/chroot/cli.sh stop'
alias cchrestart='bash ~/sh/termux/chroot/cli.sh restart'
alias cchstatus='bash ~/sh/termux/chroot/cli.sh status'
alias cchshell='bash ~/sh/termux/chroot/cli.sh shell'
alias cchexec='bash ~/sh/termux/chroot/cli.sh exec'
# chroot 卸载 (proot 不需要 umount)
alias cumount='bash ~/sh/termux/chroot/cli.sh umount'
alias cfastum='bash ~/sh/termux/chroot/cli.sh fast-umount'
alias ctimeout='bash ~/sh/termux/chroot/cli.sh set-timeout'
# chroot 强制清理
alias cchforce='bash ~/sh/termux/chroot/cli.sh force-cleanup'

# ========== proot 专属 (前缀 p*) ==========
# 整体服务编排
alias pstart='bash ~/sh/termux/chroot/proot_all_in_one.sh start'
alias pstop='bash ~/sh/termux/chroot/proot_all_in_one.sh stop'
alias prestart='bash ~/sh/termux/chroot/proot_all_in_one.sh restart'
alias pstatus='bash ~/sh/termux/chroot/proot_all_in_one.sh status'
alias penter='bash ~/sh/termux/chroot/proot_all_in_one.sh enter'
alias pinit='bash ~/sh/termux/chroot/proot_all_in_one.sh init'
# proot install: 等价于 proot-distro install debian + installer_proot.sh
alias pinstall='bash ~/sh/termux/chroot/proot_all_in_one.sh install'

# proot CLI (原始 proot_cli.sh)
alias pcli-start='bash ~/sh/termux/chroot/proot_cli.sh start'
alias pcli-stop='bash ~/sh/termux/chroot/proot_cli.sh stop'
alias pcli-restart='bash ~/sh/termux/chroot/proot_cli.sh restart'
alias pcli-status='bash ~/sh/termux/chroot/proot_cli.sh status'
alias pshell='bash ~/sh/termux/chroot/proot_cli.sh shell'
alias pexec='bash ~/sh/termux/chroot/proot_cli.sh exec'
alias pforce='bash ~/sh/termux/chroot/proot_cli.sh force-cleanup'
# 单服务管理
alias psvc='bash ~/sh/termux/chroot/proot_cli.sh svc'

# X11 和图形界面
alias x11start='bash ~/sh/termux/server_x11.sh'
alias x11stop='sudo killall Xvfb'

# 挂载配置管理 (chroot 专用)
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

# 只在 Termux 环境下显示提示
if [ -n "$PREFIX" ] && [[ "$PREFIX" == *"termux"* ]]; then
    echo "✅ Termux 别名配置已加载！"
    echo "📋 可用的主要命令:"
    echo "   🔧 整体服务: tstart, tstop, tstatus"
    echo "   🐧 Linux 容器: cstart, cstop, cshell"
    echo "   🟢 Proot 专: pstart, pshell, pinstall"
    echo "   🔵 Chroot 专: tchstart, tchinstall, cchshell, cumount"
    echo "   ⚡ 应急清理: cforce / cchforce / pforce"
fi
EOF

echo "🎉 别名配置完成！"
echo ""
echo "📌 配置文件位置: ${TOOLSRC}"
echo ""
echo "🔄 重新加载配置:"
echo "   source ~/.zshrc  # 或 source ~/.bashrc"
echo ""
echo "✨ 主要命令 (t* / c* 固定 chroot, p* 固定 proot):"
echo "   tstart   - 启动所有服务"
echo "   tstop    - 停止所有服务"
echo "   tstatus  - 查看状态"
echo "   tinstall - 安装 chroot Linux 环境"
echo "   cshell   - 进入 Linux 环境"
echo "   cforce   - 应急清理"
echo ""
echo "🟢 Proot 专属命令 (强制使用 proot-distro):"
echo "   pstart, pstop, penter, pinstall, pshell, pexec, pforce, psvc"
echo ""
echo "🔵 Chroot 专属命令 (强制使用 chroot):"
echo "   tchstart, tchinstall, cchshell, cumount, cfastum, ctimeout, cchforce"
echo ""
echo "📋 查看所有别名:"
echo "   alias | grep -E '^(t|c|p|x11)'"
