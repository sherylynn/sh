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

# 检测是否有可用的 root 权限
#   有 root -> 使用 chroot 方案 (更高效)
#   无 root -> 使用 proot-distro 方案 (无需内核权限)
has_root() {
    # 方式一: 当前用户就是 root (adb shell su -c 或 root 默认 shell)
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi
    # Termux 的 sudo/tsu 不一定支持 GNU sudo 的 -n 选项，
    # 直接校验提权后的 uid，避免把可用的 root 误判为 proot。
    if command -v sudo >/dev/null 2>&1 && [ "$(sudo id -u 2>/dev/null)" = "0" ]; then
        return 0
    fi
    if command -v tsu >/dev/null 2>&1 && [ "$(tsu -c 'id -u' 2>/dev/null)" = "0" ]; then
        return 0
    fi
    # Magisk/KernelSU 设备可能只有 su，没有安装 tsu/sudo。
    if command -v su >/dev/null 2>&1 && [ "$(su -c 'id -u' 2>/dev/null)" = "0" ]; then
        return 0
    fi
    return 1
}

# 配置别名
setup_permissions

# 创建快捷方式
# bash "$(dirname "${BASH_SOURCE[0]}")/create_shortcuts.sh" >/dev/null 2>&1 || {
#   echo "[WARN] 快捷方式脚本生成失败，可忽略。"
# }

# 根据是否有 root 权限选择容器方案:
#   - 有 root: tstart/cstart → chroot 方案 (termux_all_in_one.sh + cli.sh)
#   - 无 root: tstart/cstart → proot 方案 (proot_all_in_one.sh + proot_cli.sh)
# 另外 p* 别名始终是 proot 方案; tinstall 统一安装入口
# 检测脚本 (每次别名加载时检测一次是否能拿到 root)
_termux_has_root_alias_helper() {
    if [ "$(id -u)" -eq 0 ]; then
        echo "chroot"
        return
    fi
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        echo "chroot"
        return
    fi
    if command -v tsu >/dev/null 2>&1 && tsu -c true 2>/dev/null; then
        echo "chroot"
        return
    fi
    echo "proot"
}

tee ${TOOLSRC} <<-'EOF'
# === Termux 便捷别名 (通过toolsRC管理) ===
# 方案自动切换: 有 root 用 chroot, 无 root 用 proot-distro
# 可手动 export TERMUX_CONTAINER=chroot|proot 强制指定

_termux_pick_backend() {
    # 用户强制指定优先
    case "$TERMUX_CONTAINER" in
        chroot) echo "chroot"; return ;;
        proot)  echo "proot";  return ;;
    esac
    # 自动检测。Termux 的 sudo 通常由 tsu 提供，不支持 GNU sudo -n；
    # 使用 sudo -n 会在已有 root 的设备上误判为 proot。
    if [ "$(id -u)" -eq 0 ]; then echo "chroot"; return; fi
    if command -v sudo >/dev/null 2>&1 && [ "$(sudo id -u 2>/dev/null)" = "0" ]; then echo "chroot"; return; fi
    if command -v tsu  >/dev/null 2>&1 && [ "$(tsu -c 'id -u' 2>/dev/null)" = "0" ]; then echo "chroot"; return; fi
    if command -v su   >/dev/null 2>&1 && [ "$(su -c 'id -u' 2>/dev/null)" = "0" ]; then echo "chroot"; return; fi
    echo "proot"
}

_termux_run_allinone() {
    local backend=$(_termux_pick_backend)
    local action="$1"
    shift 2>/dev/null || true
    case "$backend" in
        chroot) bash ~/sh/termux/chroot/termux_all_in_one.sh "$action" "$@" ;;
        proot)  bash ~/sh/termux/chroot/proot_all_in_one.sh  "$action" "$@" ;;
    esac
}

_termux_run_cli() {
    local backend=$(_termux_pick_backend)
    case "$backend" in
        chroot) bash ~/sh/termux/chroot/cli.sh      "$@" ;;
        proot)  bash ~/sh/termux/chroot/proot_cli.sh "$@" ;;
    esac
}

# ========== 统一入口 (自动切换 chroot/proot) ==========
# 整体服务编排
alias tstart='_termux_run_allinone start'
alias tstop='_termux_run_allinone stop'
alias trestart='_termux_run_allinone restart'
alias tstatus='_termux_run_allinone status'
alias tenter='_termux_run_allinone enter'
alias tinit='_termux_run_allinone init'
# 统一安装入口: 有 root 用 chroot 版(ruri), 无 root 用 proot-distro 版
alias tinstall='_termux_run_allinone install'
alias tbackend='_termux_pick_backend'

# 专用容器管理 (shell / exec / restart 等)
alias cstart='_termux_run_cli start'
alias cstop='_termux_run_cli stop'
alias crestart='_termux_run_cli restart'
alias cstatus='_termux_run_cli status'
alias cshell='_termux_run_cli shell'
alias cexec='_termux_run_cli exec'
# cforce: 通用应急清理
alias cforce='_termux_run_cli force-cleanup'

# ========== chroot 专属 (前缀 tchroot* , 不想自动切换时使用) ==========
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
    __backend=$(_termux_pick_backend)
    echo "✅ Termux 别名配置已加载！(后端: $__backend)"
    [ "$__backend" = "chroot" ] && echo "� 检测到 root 权限, 默认使用 chroot 方案"
    [ "$__backend" = "proot"  ] && echo "💡 未检测到 root 权限, 默认使用 proot-distro 方案"
    echo "�📋 可用的主要命令:"
    echo "   🔧 整体服务: tstart, tstop, tstatus (自动切换后端)"
    echo "   🐧 Linux 容器: cstart, cstop, cshell (自动切换后端)"
    echo "   🟢 Proot 专: pstart, pshell, pinstall"
    echo "   🔵 Chroot 专: tchstart, tchinstall, cchshell, cumount"
    echo "   ⚡ 应急清理: cforce (自动), cchforce / pforce (手动)"
    echo "💡 手动切换后端: export TERMUX_CONTAINER=chroot|proot"
fi
EOF

echo "🎉 别名配置完成！"
echo ""
echo "📌 配置文件位置: ${TOOLSRC}"
echo ""
echo "🔄 重新加载配置:"
echo "   source ~/.zshrc  # 或 source ~/.bashrc"
echo ""
echo "✨ 主要命令 (自动切换后端, 有 root 用 chroot, 无 root 用 proot):"
echo "   tstart   - 启动所有服务"
echo "   tstop    - 停止所有服务"
echo "   tstatus  - 查看状态"
echo "   tinstall - 安装 Linux 环境 (chroot: ruri debian / proot: proot-distro debian)"
echo "   cshell   - 进入 Linux 环境"
echo "   cforce   - 应急清理"
echo ""
echo "🟢 Proot 专属命令 (强制使用 proot-distro):"
echo "   pstart, pstop, penter, pinstall, pshell, pexec, pforce, psvc"
echo ""
echo "🔵 Chroot 专属命令 (强制使用 chroot):"
echo "   tchstart, tchinstall, cchshell, cumount, cfastum, ctimeout, cchforce"
echo ""
echo "⚡ 手动切换后端 (不用改配置):"
echo "   export TERMUX_CONTAINER=chroot   # 强制 chroot"
echo "   export TERMUX_CONTAINER=proot    # 强制 proot"
echo ""
echo "📋 查看所有别名:"
echo "   alias | grep -E '^(t|c|p|x11)'"
