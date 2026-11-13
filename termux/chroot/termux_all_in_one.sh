#!/data/data/com.termux/files/usr/bin/bash

# Termux 一键启动脚本 - 整合所有功能
# 使用方法: bash ~/sh/termux/chroot/termux_all_in_one.sh [start|stop|restart|status]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# 日志函数
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
  log "ERROR: $1" >&2
  exit 1
}

# ERR trap: set -e 静默退出时打印失败位置, 便于定位
trap 'log "ERR: 命令失败 行号=$LINENO 命令=\$BASH_COMMAND" >&2' ERR

# 加载工具函数
log "加载 toolsinit.sh..."
. "$PROJECT_ROOT/win-git/toolsinit.sh"
# cli.sh 含预期的非零返回 (sudo test -f ... && ..., detect_distro_rootfs return 1)
# 临时关闭 set -e 避免 source 时误退出
log "加载 cli.sh..."
trap - ERR
set +e
. "$SCRIPT_DIR/cli.sh"
set -e
trap 'log "ERR: 命令失败 行号=$LINENO 命令=\$BASH_COMMAND" >&2' ERR
log "cli.sh 加载完成, DEBIAN_DIR=$DEBIAN_DIR"

# Never pass XDG_RUNTIME_DIR=/tmp to Wayland/PipeWire descendants. Some runtimes
# chmod their XDG_RUNTIME_DIR to 0700, which would break the bind-shared /tmp for
# Debian _apt and Termux. A per-UID child directory is the correct runtime.
ensure_private_xdg_runtime() {
  case "${XDG_RUNTIME_DIR:-}" in
    /tmp|"${PREFIX}/tmp")
      local runtime="${PREFIX}/tmp/newhome-runtime-$(id -u)"
      install -d -m 0700 "$runtime" || error "无法创建独立 XDG_RUNTIME_DIR: $runtime"
      export XDG_RUNTIME_DIR="$runtime"
      log "隔离 XDG_RUNTIME_DIR: $runtime (不再使用共享 tmp 根目录)"
      ;;
  esac
}

# 检查必要的权限和环境
check_requirements() {
  log "检查运行环境..."

  # 检查root权限 (依次尝试 sudo / tsu / su, 打印命中方式)
  local root_method=""
  if [ "$(id -u 2>/dev/null)" = "0" ]; then
    root_method="uid0"
  elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    root_method="sudo-nopass"
  elif command -v tsu >/dev/null 2>&1 && tsu -c true 2>/dev/null; then
    root_method="tsu"
  fi
  if [ -z "$root_method" ]; then
    # 最后兜底: 交互式 sudo (原行为, 可能阻塞等密码)
    if sudo true 2>/dev/null; then
      root_method="sudo-interactive"
    fi
  fi
  if [ -z "$root_method" ]; then
    error "需要root权限，请确保已获取root权限 (尝试过 uid0/sudo-n/tsu/sudo)"
  fi
  log "root 权限检测通过 (方式: $root_method)"

  # NewHome 自己拥有本地 compositor；Termux:X11 不再是运行依赖。
  # 启动阶段只验证基础服务/Android activity manager。
  local required_command
  for required_command in sv am; do
    command -v "$required_command" >/dev/null 2>&1 ||
      error "缺少命令 $required_command，请先运行 installer_proot.sh"
  done

  log "环境检查完成"
}

# 启动基础服务
start_base_services() {
  log "启动基础服务（显示与音频主链由 NewHome 管理）..."

  local services=()
  if [ -f "/sdcard/Download/使用虚拟显卡.txt" ]; then
    log "虚拟显卡模式：启用 virgl；音频由 NewHome 管理"
    services=("virgl")
  elif lscpu | grep -q "Oryon"; then
    log "Oryon CPU detected, skipping virgl service startup."
    services=()
  else
    services=("virgl")
  fi

  local service
  for service in "${services[@]}"; do
    if [ -d "$PREFIX/var/service/$service" ]; then
      log "启动服务: $service"
      sv up "$PREFIX/var/service/$service" 2>/dev/null || true
    fi
  done

  # Termux Pulse 已退出主播放链；NewHome Android AudioTrack 是唯一 speaker owner。
  if [ -d "$PREFIX/var/service/pulseaudio" ]; then
    sv down "$PREFIX/var/service/pulseaudio" 2>/dev/null || true
  fi
}

disable_legacy_display_autostart() {
  # noVNC is now only the Web frontend for NewHome native RFB and remains an rc3 service.
  # Remove only obsolete display owners from existing rootfs images.
  sudo rm -f \
    "$DEBIAN_DIR"/etc/rc*.d/S??lightdm \
    "$DEBIAN_DIR"/etc/rc*.d/S??xrdp 2>/dev/null || true
}

quiesce_legacy_chroot_display() {
  chroot_exec -u root '
    pkill -TERM -x x11vnc >/dev/null 2>&1 || true
    pkill -TERM -x wayvnc >/dev/null 2>&1 || true
    pkill -TERM -x xrdp >/dev/null 2>&1 || true
    pkill -TERM -x Xvnc >/dev/null 2>&1 || true
    pkill -TERM -x Xtigervnc >/dev/null 2>&1 || true
  ' >/dev/null 2>&1 || true
}

# rc3 starts /etc/init.d/noVNC from the rootfs, so always copy the checkout's
# native-RFB frontend before start_chroot/start_init runs.
sync_remote_desktop_scripts() {
  local destination_dir="$DEBIAN_DIR/root/sh/win-git"
  sudo mkdir -p "$destination_dir"
  for source_name in server_noVNC.sh init_d_noVNC.sh; do
    if [ -f "$PROJECT_ROOT/win-git/$source_name" ]; then
      sudo cp "$PROJECT_ROOT/win-git/$source_name" "$destination_dir/$source_name"
      sudo chmod 755 "$destination_dir/$source_name"
    fi
  done

  # Native RFB owns authentication. Preserve the historical VNC password when
  # upgrading old rootfs images; noVNC/websockify itself has no HTTP Basic Auth.
  sudo mkdir -p "$DEBIAN_DIR/root/.vnc"
  local legacy_vnc_credentials="$DEBIAN_DIR/root/.vnc/wayvnc.credentials"
  if [ ! -s "$legacy_vnc_credentials" ] && container_mounted &&
     [ -s "$CHROOT_DIR/root/.vnc/wayvnc.credentials" ]; then
    legacy_vnc_credentials="$CHROOT_DIR/root/.vnc/wayvnc.credentials"
  fi
  if [ -s "$legacy_vnc_credentials" ]; then
    # One-time migration: prefer the user's historical VNC password even if an
    # earlier migration attempt already generated a temporary native password.
    sudo cp "$legacy_vnc_credentials" "$DEBIAN_DIR/root/.vnc/vnc.credentials"
    sudo rm -f "$legacy_vnc_credentials"
  elif [ ! -s "$DEBIAN_DIR/root/.vnc/vnc.credentials" ]; then
    if [ -s "$DEBIAN_DIR/root/.vnc/novnc.credentials" ]; then
      sudo cp "$DEBIAN_DIR/root/.vnc/novnc.credentials" "$DEBIAN_DIR/root/.vnc/vnc.credentials"
    else
      local bootstrap_password
      bootstrap_password=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 32)
      [ -n "$bootstrap_password" ] || bootstrap_password="newhome"
      printf 'password=%s\n' "$bootstrap_password" |
        sudo tee "$DEBIAN_DIR/root/.vnc/vnc.credentials" >/dev/null
      log "已生成 native VNC 密码文件: /root/.vnc/vnc.credentials"
    fi
  fi
  sudo chmod 0600 "$DEBIAN_DIR/root/.vnc/vnc.credentials"
}


ensure_native_novnc_service() {
  # Older rootfs images may still have /etc/init.d/noVNC but have lost the rc3
  # symlink during the legacy-display cleanup. Reinstall the canonical service
  # definition on every tstart, then start it explicitly after native RFB is ready.
  chroot_exec -u root '
    set -eu
    /bin/bash /root/sh/win-git/init_d_noVNC.sh >/dev/null
    test -L /etc/rc3.d/S01noVNC
    /etc/init.d/noVNC start
  ' || error "无法恢复/启动 native noVNC rc3 服务"
}

wait_remote_desktop_services() {
  local wait_step backend_state backend
  backend_state="$DEBIAN_DIR/root/.vnc/novnc-backend.env"
  for wait_step in {1..80}; do
    backend=$(sudo sed -n 's/^backend=//p' "$backend_state" 2>/dev/null | head -1)
    if [ "$backend" = "native" ] &&
      chroot_exec -u root '
        pgrep -f "newhome_websockify.py.*10086" >/dev/null 2>&1 &&
        { grep -qE ":2766 .* 0A " /proc/net/tcp 2>/dev/null ||
          grep -qE ":2766 .* 0A " /proc/net/tcp6 2>/dev/null; }
      ' >/dev/null 2>&1; then
      log "远程桌面健康检查通过: NewHome native RFB -> noVNC=:10086"
      return 0
    fi
    sleep 0.5
  done
  log "ERROR: NewHome native RFB/noVNC 健康检查失败 (backend=${backend:-unknown})" >&2
  sudo tail -120 "$DEBIAN_DIR/root/.vnc/server-noVNC-startup.log" 2>/dev/null || true
  sudo tail -80 "$DEBIAN_DIR/root/.vnc/novnc-proxy.log" 2>/dev/null || true
  return 1
}

prepare_newhome_wayland_runtime() {
  # cli.sh establishes the App-owned transport bind in the Termux host mount namespace before
  # entering chroot. At this point /run/newhome-compositor must already be that shared inode.
  chroot_exec -u root '
    set -eu
    test -d /run/newhome-compositor
    cat > /etc/profile.d/newhome-wayland.sh <<"EOF"
export WAYLAND_DISPLAY=/run/newhome-compositor/wayland-0
if [ -r /run/newhome-compositor/xdisplay ]; then
  export DISPLAY="$(cat /run/newhome-compositor/xdisplay)"
else
  unset DISPLAY
fi
_newhome_uid=$(/usr/bin/id -u 2>/dev/null || echo 0)
export XDG_RUNTIME_DIR="/tmp/newhome-runtime-${_newhome_uid}"
/bin/mkdir -p "$XDG_RUNTIME_DIR"
/bin/chmod 0700 "$XDG_RUNTIME_DIR"
unset _newhome_uid
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce
# Prefer native Wayland, but retain Xwayland fallback for X11-only apps/plugins.
export GDK_BACKEND=wayland,x11
export QT_QPA_PLATFORM="wayland;xcb"
unset SDL_VIDEODRIVER
export ELECTRON_OZONE_PLATFORM_HINT=auto
export MOZ_ENABLE_WAYLAND=1
unset PULSE_SERVER # obsolete Termux Pulse endpoint; NewHome uses authenticated dynamic endpoint
EOF
    chmod 0644 /etc/profile.d/newhome-wayland.sh
  ' || error "Unable to prepare NewHome Wayland runtime"
  log "Wayland runtime prepared inside chroot: /run/newhome-compositor"
}

unmount_newhome_wayland_runtime() {
  # The dedicated bind is part of the container mount graph and is removed by container_umount.
  # Do not unlink App-owned transport files here.
  :
}


wait_newhome_xwayland_ready() {
  log "验证 managed Xwayland/XWM..."
  chroot_exec -u root '
    set -eu
    command -v xprop >/dev/null 2>&1 || {
      echo "缺少 xprop，无法验证 Xwayland/XWM；请安装 x11-utils" >&2
      exit 1
    }
    [ -r /run/newhome-compositor/xdisplay ] || {
      echo "缺少 /run/newhome-compositor/xdisplay" >&2
      exit 1
    }
    display=$(cat /run/newhome-compositor/xdisplay)
    i=0
    while [ "$i" -lt 100 ]; do
      if DISPLAY="$display" xprop -root _NET_SUPPORTING_WM_CHECK >/tmp/newhome-xwayland-xwm-check.log 2>&1; then
        exit 0
      fi
      i=$((i + 1))
      sleep 0.1
    done
    cat /tmp/newhome-xwayland-xwm-check.log >&2 2>/dev/null || true
    exit 1
  ' || {
    sudo /system/bin/cat /data/user/0/com.example.customlauncher/files/linux-runtime/xwayland.log 2>/dev/null | tail -80 >&2 || true
    error "Xwayland/XWM 未能接受当前 DISPLAY 连接；为保证 X11-only 应用可用，本次不进入残缺桌面会话"
  }
  local display
  display=$(chroot_exec -u root 'cat /run/newhome-compositor/xdisplay')
  log "managed Xwayland/XWM 已就绪: $display"
}



# Chroot mount is the Termux owner's only startup responsibility. Rust
# newhome-serviced is the sole NewHome service Child owner and is bootstrapped
# directly, not through any rc3/SysV init launcher. The currently selected
# Linux small-window source remains an explicit Android product choice.
start_managed_chroot_services() {
  log "启动/复用 Rust newhome-serviced 管理的 CHROOT 服务（无第二合成器）..."
  chroot_exec -u root '
    set -eu
    [ -x /usr/bin/newhome-serviced-bootstrap ] || {
      echo "missing /usr/bin/newhome-serviced-bootstrap; update the NewHome CHROOT package" >&2
      exit 78
    }
    /usr/bin/newhome-serviced-bootstrap start
    newhome-systemctl daemon-reload
    # Bridges remain available even when the App uses U, allowing the
    # Linux manager to switch sources without relying on stale rc3 state.
    newhome-systemctl enable newhome-linux-runtime-bridge.service newhome-linux-service-manager-bridge.service
    newhome-systemctl start newhome-linux-runtime-bridge.service newhome-linux-service-manager-bridge.service
    newhome-systemctl is-active newhome-linux-runtime-bridge.service newhome-linux-service-manager-bridge.service
    # A root-only credential exists only after the authorized Android App
    # has provisioned the canonical compositor. Do not invent a new token.
    if [ -r /etc/newhome/wayland-owner.conf ]; then
      newhome-systemctl enable newhome-wayland-core.service newhome-wayland-desktop.service
      newhome-systemctl start newhome-wayland-core.service newhome-wayland-desktop.service
      newhome-systemctl is-active newhome-wayland-core.service newhome-wayland-desktop.service
    else
      echo "No CHROOT renderer enrollment yet; open CHROOT from Linux manager to provision"
    fi
  ' || error "Rust serviced CHROOT service bootstrap failed; never start legacy fallback"
}

stop_managed_chroot_services() {
  log "停止 Rust serviced 所拥有的 CHROOT 服务（不使用 pkill/SysV）..."
  chroot_exec -u root '
    set -eu
    [ -x /usr/bin/newhome-serviced-bootstrap ] || exit 78
    if /usr/bin/newhome-serviced-bootstrap status >/dev/null 2>&1; then
      for unit in newhome-wayland-desktop.service newhome-wayland-core.service newhome-linux-runtime-bridge.service newhome-linux-service-manager-bridge.service; do
        newhome-systemctl disable "$unit" || exit
        newhome-systemctl stop "$unit" || exit
      done
      /usr/bin/newhome-serviced-bootstrap stop
    fi
  ' || error "Rust serviced CHROOT 关闭未确认，拒绝直接强杀 compositor"
}

wait_newhome_persistent_core() {
  log "等待 NewHome persistent CHROOT core..."
  local i
  for i in {1..150}; do
    if chroot_exec -u root '
      test -S /run/newhome-compositor/wayland-0 &&
      grep -Fq " /run/newhome-compositor/wayland-0" /proc/net/unix 2>/dev/null
    ' >/dev/null 2>&1; then
      log "Persistent CHROOT core 已就绪: /run/newhome-compositor/wayland-0"
      return 0
    fi
    sleep 0.1
  done
  error "Persistent CHROOT core 未能启动；不再回退到 legacy Wayland acceptor"
}


start_rooted_newhome_desktop() {
  ensure_shared_chroot_tmp || error "Termux 共享 tmp 无法修复"
  ensure_private_xdg_runtime
  sync_remote_desktop_scripts
  disable_legacy_display_autostart
  start_chroot
  prepare_newhome_wayland_runtime
  start_managed_chroot_services

  # Existing CHROOT owner may be running headless before any Android small
  # window attaches. Do not call LINUX_RUNTIME_ENSURE (it is the U/P App
  # owner) or manually restart XFCE/XWayland. UI switch performs RendererLease
  # attestation + attach through the already running Rust service manager.
  if chroot_exec -u root 'newhome-systemctl is-active newhome-wayland-core.service newhome-wayland-desktop.service' >/dev/null 2>&1; then
    wait_newhome_persistent_core
    wait_newhome_xwayland_ready
    # Old noVNC remains an independent optional frontend during migration;
    # it is NOT a second desktop/compositor lifecycle owner.
    if ! ensure_native_novnc_service || ! wait_remote_desktop_services; then
      log "可选 noVNC 前端未就绪；不影响 Rust serviced CHROOT 与 Linux 小窗"
    fi
  else
    log "CHROOT 服务桥已就绪；等待 Linux 管理工具显式选择并 provision CHROOT 桌面"
  fi
}


# 启动chroot linux (调用cli.sh中的函数)
start_chroot() {
  log "启动chroot Linux环境..."
  log "容器 rootfs 路径: $DEBIAN_DIR"
  log "挂载点路径: $CHROOT_DIR"

  # 直接调用cli.sh中的完整实现
  if ! start_chroot_container; then
    error "无法启动chroot环境"
  fi

  log "Chroot Linux环境启动完成 (包括初始化系统服务)"
  log "可以使用以下命令进入Linux环境:"
  log "  tenter 或 cshell"
}

# 停止所有服务
stop_all() {
  log "停止所有服务..."
  # Explicit operator stop is the only destructive CHROOT shutdown path;
  # close/reattach of the Linux floating window must never call this.
  if container_mounted; then
    stop_managed_chroot_services
  fi
  stop_chroot_container || error "CHROOT 容器停止失败"
  if [ -d "$PREFIX/var/service/virgl" ]; then
    sv down "$PREFIX/var/service/virgl" 2>/dev/null || true
  fi
  kill_need 2>/dev/null || true
  clean_tmp
  log "所有服务已停止"
}

# 分阶段 user stop 只处理无需 rootfs mount owner 的服务。compositor 由 Android service
# 自身关闭；XWayland 由 compositor 一并管理，绝不从 Termux 外部 kill。
stop_user_services() {
  log "停止 Termux 用户基础服务..."
  # User-stage stop must not kill an independently supervised CHROOT owner.
  if [ -d "$PREFIX/var/service/virgl" ]; then
    sv down "$PREFIX/var/service/virgl" 2>/dev/null || true
  fi
  log "Termux 用户基础服务已停止"
}

check_status() {
  echo "=== NewHome Linux 环境状态 ==="
  echo "本地显示: NewHome native Wayland compositor"
  local current_display
  current_display=$(chroot_exec -u root 'cat /run/newhome-compositor/xdisplay 2>/dev/null || true')
  if [ -n "$current_display" ] &&
     chroot_exec -u root "test -S /tmp/.X11-unix/X${current_display#:}" >/dev/null 2>&1; then
    echo "兼容 X11: compositor-managed XWayland DISPLAY=$current_display"
  else
    echo "兼容 X11: managed XWayland socket not ready"
  fi
  echo "CHROOT NewHome Rust service owner (not Android presentation):"
  chroot_exec -u root '
    if [ -x /usr/bin/newhome-serviced-bootstrap ]; then
      /usr/bin/newhome-serviced-bootstrap status || true
      newhome-systemctl status newhome-linux-runtime-bridge.service newhome-linux-service-manager-bridge.service newhome-wayland-core.service newhome-wayland-desktop.service || true
    else
      echo "  newhome-serviced-bootstrap not installed"
    fi
  ' 2>/dev/null || echo "  Rust owner unavailable"
  check_chroot_status
  local shared_tmp_mode
  shared_tmp_mode=$(sudo stat -c '%a' "${PREFIX}/tmp" 2>/dev/null || true)
  if [ "$shared_tmp_mode" = 1777 ]; then
    echo "Termux/chroot 共享 tmp: 1777 (OK)"
  else
    echo "Termux/chroot 共享 tmp: ${shared_tmp_mode:-不可访问} (需要 1777)"
  fi
  echo
  echo "NewHome Wayland transport:"
  chroot_exec -u root 'if grep -Fq " /run/newhome-compositor/wayland-0" /proc/net/unix 2>/dev/null; then echo "  wayland-0: listening"; else echo "  wayland-0: down"; fi' 2>/dev/null || echo "  wayland-0: unavailable"
  echo "XFCE Wayland:"
  chroot_exec -u root 'if pgrep -x xfce4-session >/dev/null 2>&1; then echo "  xfce4-session: running"; else echo "  xfce4-session: down"; fi; if pgrep -x xfce4-panel >/dev/null 2>&1; then echo "  xfce4-panel: running"; else echo "  xfce4-panel: down"; fi' 2>/dev/null || echo "  unavailable"
  echo "noVNC frontend:"
  if pgrep -f 'newhome_websockify.py' >/dev/null 2>&1; then
    echo "  websockify: running (:10086 -> native RFB)"
  else
    echo "  websockify: down"
  fi
}

# 进入chroot环境 (调用cli.sh中的函数)
enter_chroot() {
  log "进入chroot Linux环境..."
  ensure_shared_chroot_tmp || error "共享 /tmp 权限或挂载异常"
  enter_chroot_shell
}

# 在chroot中执行命令 (调用cli.sh中的函数)
exec_in_chroot() {
  if [ $# -eq 0 ]; then
    error "请提供要执行的命令"
  fi

  ensure_shared_chroot_tmp || error "共享 /tmp 权限或挂载异常"
  exec_chroot_command "$@"
}

# 安装debian环境
install_debian() {
  log "开始安装Debian环境..."

  if [ -e "$DEBIAN_DIR/bin/dpkg" ]; then
    log "Debian环境已存在"
    return 0
  fi

  # 运行安装脚本
  bash "$SCRIPT_DIR/chroot/installer_proot.sh"

  log "Debian环境安装完成"
}

# 安装proot环境
install_proot() {
  log "开始安装Proot Linux环境..."

  # 运行安装脚本
  bash "$SCRIPT_DIR/chroot/installer_proot.sh"

  log "Proot Linux环境安装完成"
}

# 显示使用帮助
show_usage() {
  cat <<EOF
Termux 一键启动脚本 - 整体服务编排器

使用方法:
  $0 [命令]

可用命令:
  start         启动基础服务 + CHROOT + Rust serviced 管理的 Linux
  stop          停止所有服务
  restart       重启所有服务
  status        查看 Rust serviced 四项服务 + CHROOT 状态
  enter         进入chroot Linux环境
  exec <命令>   在chroot中执行命令
  install       安装Debian环境
  init          安装Proot Linux环境

示例:
  $0 start                    # 启动完整环境
  $0 enter                    # 进入Linux环境
  $0 exec "apt update"        # 在Linux中执行命令
  $0 status                   # 查看完整状态
  $0 init                     # 安装Proot环境

快捷别名:
  tstart, tstop, trestart, tstatus, tenter, tinit

专用chroot管理 (更多功能):
  bash ~/sh/termux/chroot/cli.sh [start|stop|shell|exec|force-cleanup]
  别名: cstart, cstop, cshell, cexec, cforce

职责分工:
  - termux_all_in_one.sh: Termux 基础服务 + CHROOT 挂载 + Rust serviced bootstrap
  - cli.sh: 容器挂载/进入 + 非 NewHome 的旧 rc3 兼容服务
  - NewHome Linux 管理: 显式选择 U/P 或 CHROOT；小窗只 attach/detach
EOF
}

# 主函数
main() {
  local command="${1:-start}"

  case "$command" in
    "start")
      check_requirements
      start_base_services
      start_rooted_newhome_desktop
      log "CHROOT + Rust serviced 启动/复用完成；小窗由 Linux 管理工具显式换源"
      log "使用 '$0 enter' 进入Linux环境"
      ;;
    "stop")
      stop_all
      ;;
    "restart")
      stop_all
      sleep 2
      main start
      ;;
    "status")
      check_status
      ;;
    "enter")
      enter_chroot
      ;;
    "exec")
      shift
      exec_in_chroot "$@"
      ;;
    "install")
      check_requirements
      install_debian
      ;;
    "init")
      check_requirements
      install_proot
      ;;
    "help" | "-h" | "--help")
      show_usage
      ;;
    *)
      echo "未知命令: $command"
      show_usage
      exit 1
      ;;
  esac
}

# 检查是否直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
