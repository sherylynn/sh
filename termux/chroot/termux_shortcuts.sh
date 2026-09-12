#!/data/data/com.termux/files/usr/bin/bash
# 只由 Termux 的 toolsinit.sh 加载；不要在 chroot/proot Linux 中注入。

_newhome_termux_root=${HOME}/sh/termux/chroot
[ -d "$_newhome_termux_root" ] || return 0 2>/dev/null || exit 0

# 默认桌面：chroot + Termux:X11。
alias tstart='bash ~/sh/termux/chroot/termux_all_in_one.sh start'
alias tstop='bash ~/sh/termux/chroot/termux_all_in_one.sh stop'
alias trestart='bash ~/sh/termux/chroot/termux_all_in_one.sh restart'
alias tstatus='bash ~/sh/termux/chroot/termux_all_in_one.sh status'
alias tenter='bash ~/sh/termux/chroot/termux_all_in_one.sh enter'
alias tinstall='bash ~/sh/termux/chroot/termux_all_in_one.sh install'

# 无 root 的 proot-distro + Termux:X11 桌面。
alias pstart='bash ~/sh/termux/chroot/proot_all_in_one.sh start'
alias pstop='bash ~/sh/termux/chroot/proot_all_in_one.sh stop'
alias prestart='bash ~/sh/termux/chroot/proot_all_in_one.sh restart'
alias pstatus='bash ~/sh/termux/chroot/proot_all_in_one.sh status'
alias penter='bash ~/sh/termux/chroot/proot_all_in_one.sh enter'
alias pinstall='bash ~/sh/termux/chroot/proot_all_in_one.sh install'

# chroot + Anland/Labwc direct Wayland 桌面。
alias wstart='bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh start'
alias wstop='bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh stop'
alias wrestart='bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh restart'
alias wstatus='bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh status'
alias wdoctor='bash ~/sh/termux/chroot/termux_wayland_all_in_one.sh doctor'

unset _newhome_termux_root
