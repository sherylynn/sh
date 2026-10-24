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
  if [ -s "$DEBIAN_DIR/root/.vnc/wayvnc.credentials" ]; then
    # One-time migration: prefer the user's historical VNC password even if an
    # earlier migration attempt already generated a temporary native password.
    sudo cp "$DEBIAN_DIR/root/.vnc/wayvnc.credentials" "$DEBIAN_DIR/root/.vnc/vnc.credentials"
    sudo rm -f "$DEBIAN_DIR/root/.vnc/wayvnc.credentials"
  elif [ ! -s "$DEBIAN_DIR/root/.vnc/vnc.credentials" ]; then
    if [ -s "$DEBIAN_DIR/root/.vnc/novnc.credentials" ]; then
      sudo cp "$DEBIAN_DIR/root/.vnc/novnc.credentials" "$DEBIAN_DIR/root/.vnc/vnc.credentials"
    else
      local bootstrap_password
      bootstrap_password=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 8)
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
  # connected-FD transport means Android never needs the client-visible Wayland
  # socket path. Keep it entirely inside the chroot; only accepted socket FDs
  # cross into the Android-side Smithay compositor.
  chroot_exec -u root '
    set -eu
    install -d -m 0755 /run/newhome-compositor
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
  # No Android app-data bind mount exists in Compositor Bridge V2.
  # The chroot stop path tears down remaining processes; only remove stale files.
  chroot_exec -u root '
    if ! grep -Fq " /run/newhome-compositor/wayland-0" /proc/net/unix 2>/dev/null; then
      rm -f /run/newhome-compositor/wayland-0
    fi
  ' >/dev/null 2>&1 || true
}

read_native_vnc_password() {
  local credentials="$DEBIAN_DIR/root/.vnc/vnc.credentials"
  local password
  password=$(sudo sed -n 's/^password=//p' "$credentials" 2>/dev/null | head -1)
  [ -n "$password" ] || error "native VNC 密码未配置: /root/.vnc/vnc.credentials"
  printf '%s' "$password"
}

start_newhome_compositor() {
  log "启动 NewHome Android-side Smithay runtime（headless，不打开 Linux 小窗）..."
  local rfb_password
  rfb_password=$(read_native_vnc_password)
  sudo /system/bin/am start-foreground-service --user 0 \
    -n com.example.customlauncher/.linux.LinuxDesktopFloatingService \
    -a com.example.customlauncher.action.LINUX_RUNTIME_ENSURE \
    --es rfb_password "$rfb_password" >/dev/null 2>&1 || \
    error "无法启动 NewHome Smithay runtime；请先安装当前 NewHome"
  log "NewHome compositor 已常驻；Linux 小窗 presentation 由快捷工具按需 attach"
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

mount_newhome_x11_runtime() {
  # Smithay/Xwayland chooses the first free X display dynamically. Do not assume :0:
  # stale locks/sockets can legitimately make a cold runtime become :1/:2/etc.
  local source=/data/user/0/com.example.customlauncher/files/linux-runtime/.X11-unix
  local target="$CHROOT_DIR/tmp/.X11-unix"
  local display="" socket="" i source_sig target_sig

  for i in {1..150}; do
    display=$(sudo /system/bin/ps -A -o ARGS 2>/dev/null | awk '
      /\/usr\/bin\/Xwayland :[0-9]+/ {
        for (i = 1; i <= NF; i++) if ($i ~ /^:[0-9]+$/) { print $i; exit }
      }
    ')
    if [ -n "$display" ]; then
      socket="X${display#:}"
      if sudo /system/bin/ls "$source/$socket" >/dev/null 2>&1; then
        break
      fi
    fi
    display=""
    socket=""
    sleep 0.1
  done

  [ -n "$display" ] && [ -n "$socket" ] || error "managed Xwayland 未公布当前 DISPLAY/socket"
  sudo /system/bin/ls "$source/$socket" >/dev/null 2>&1 ||
    error "managed Xwayland 未创建当前 app runtime socket: $source/$socket"

  source_sig=$(sudo /system/bin/stat -Lc '%d:%i' "$source/$socket" 2>/dev/null || true)
  target_sig=$(chroot_exec -u root "stat -Lc '%d:%i' /tmp/.X11-unix/$socket 2>/dev/null" || true)
  if [ -z "$source_sig" ] || [ "$source_sig" != "$target_sig" ]; then
    sudo mkdir -p "$target"
    sudo mount -o bind "$source" "$target" || error "无法挂载当前 NewHome Xwayland socket runtime"
    target_sig=$(chroot_exec -u root "stat -Lc '%d:%i' /tmp/.X11-unix/$socket 2>/dev/null" || true)
    [ -n "$source_sig" ] && [ "$source_sig" = "$target_sig" ] ||
      error "Xwayland socket bind 后仍不是当前 runtime: source=${source_sig:-?} target=${target_sig:-?}"
    log "当前 Xwayland socket runtime 已映射: $display ($source_sig)"
  else
    log "复用当前 Xwayland socket 映射: $display ($source_sig)"
  fi

  chroot_exec -u root "printf '%s\n' '$display' > /run/newhome-compositor/xdisplay"
}

stop_newhome_compositor() {
  sudo /system/bin/am start-foreground-service --user 0 \
    -n com.example.customlauncher/.linux.LinuxDesktopFloatingService \
    -a com.example.customlauncher.action.LINUX_RUNTIME_STOP >/dev/null 2>&1 || true
  sleep 0.2
  sudo /system/bin/am stopservice --user 0 \
    -n com.example.customlauncher/.linux.LinuxDesktopFloatingService >/dev/null 2>&1 || true
}

start_newhome_wayland_acceptor() {
  log "启动 chroot -> Android Smithay Wayland transport..."

  chroot_exec -u root '
    set -eu
    socket=/run/newhome-compositor/wayland-0
    endpoint=@newhome_compositor_bridge_v2
    acceptor=/usr/bin/newhome-wayland-acceptor
    log_file=/tmp/newhome-wayland-acceptor.log

    [ -x "$acceptor" ] || { echo "缺少 $acceptor；请先安装当前 NewHome Linux 包" >&2; exit 1; }
    [ -x /usr/bin/newhome-wayland-run ] || { echo "缺少 /usr/bin/newhome-wayland-run" >&2; exit 1; }
    [ -f /usr/lib/newhome-container/libnewhome-wayland-shm-allocator.so ] || {
      echo "缺少 Android-owned SHM allocator" >&2
      exit 1
    }

    mkdir -p /run/newhome-compositor
    chmod 0755 /run/newhome-compositor

    socket_listening() {
      [ -S "$socket" ] || return 1
      awk -v socket="$socket" "\$4 == \"00010000\" && \$5 == \"0001\" && \$6 == \"01\" && \$8 == socket { found = 1; exit } END { exit(found ? 0 : 1) }" /proc/net/unix 2>/dev/null
    }

    if socket_listening; then
      exit 0
    fi

    rm -f "$socket"
    pkill -TERM -f "^/usr/bin/newhome-wayland-acceptor $socket " 2>/dev/null || true

    attempt=0
    while [ "$attempt" -lt 30 ]; do
      attempt=$((attempt + 1))
      nohup setsid "$acceptor" "$socket" "$endpoint" >"$log_file" 2>&1 </dev/null &
      pid=$!

      i=0
      while [ "$i" -lt 20 ]; do
        if socket_listening; then
          printf "%s\n" "$pid" > /run/newhome-compositor/wayland-acceptor.pid
          exit 0
        fi
        kill -0 "$pid" 2>/dev/null || break
        i=$((i + 1))
        sleep 0.1
      done
      wait "$pid" 2>/dev/null || true
      sleep 0.1
    done

    echo "NewHome Wayland acceptor 未能连接 Android compositor" >&2
    tail -40 "$log_file" >&2 2>/dev/null || true
    exit 1
  ' || error "NewHome Wayland transport 启动失败"

  log "Wayland transport 已就绪: /run/newhome-compositor/wayland-0"
}

start_xfce_wayland_session() {
  log "启动 XFCE Wayland 会话（NewHome 是唯一 compositor）..."

  chroot_exec -u root '
    set -eu
    socket=/run/newhome-compositor/wayland-0
    log_file=/tmp/newhome-xfce-wayland.log

    awk -v socket="$socket" "\$4 == \"00010000\" && \$5 == \"0001\" && \$6 == \"01\" && \$8 == socket { found = 1; exit } END { exit(found ? 0 : 1) }" /proc/net/unix 2>/dev/null || {
      echo "Wayland transport 未监听: $socket" >&2
      exit 1
    }
    command -v xfce4-session >/dev/null 2>&1 || { echo "缺少 xfce4-session" >&2; exit 1; }
    command -v dbus-run-session >/dev/null 2>&1 || { echo "缺少 dbus-run-session" >&2; exit 1; }

    pkill -TERM -x xfce4-session 2>/dev/null || true
    pkill -TERM -x xfce4-panel 2>/dev/null || true
    pkill -TERM -x xfdesktop 2>/dev/null || true
    pkill -TERM -x xfwm4 2>/dev/null || true
    sleep 0.3

    runtime=/tmp/newhome-runtime-0
    mkdir -p "$runtime"
    chmod 0700 "$runtime"

    export WAYLAND_DISPLAY="$socket"
    [ -r /run/newhome-compositor/xdisplay ] || { echo "managed Xwayland display file missing" >&2; exit 1; }
    export DISPLAY="$(cat /run/newhome-compositor/xdisplay)"
    x11_socket="/tmp/.X11-unix/X${DISPLAY#:}"
    [ -S "$x11_socket" ] || { echo "managed Xwayland socket missing: $x11_socket" >&2; exit 1; }
    export XDG_RUNTIME_DIR="$runtime"
    export XDG_SESSION_TYPE=wayland
    export XDG_CURRENT_DESKTOP=XFCE
    export XDG_SESSION_DESKTOP=xfce
    export GDK_BACKEND=wayland,x11
    export QT_QPA_PLATFORM="wayland;xcb"
    unset SDL_VIDEODRIVER
    export ELECTRON_OZONE_PLATFORM_HINT=auto
    export MOZ_ENABLE_WAYLAND=1
    unset PULSE_SERVER # obsolete Termux Pulse endpoint; NewHome uses authenticated dynamic endpoint

    # startxfce4 --wayland 会额外启动 labwc；这里必须直接进入 xfce4-session。
    nohup setsid /usr/bin/dbus-run-session --       /usr/bin/newhome-wayland-run /usr/bin/xfce4-session       >"$log_file" 2>&1 </dev/null &
    session_pid=$!
    printf "%s\n" "$session_pid" > /run/newhome-compositor/xfce-session.pid

    i=0
    while [ "$i" -lt 80 ]; do
      if pgrep -x xfce4-session >/dev/null 2>&1 &&
         pgrep -x xfce4-panel >/dev/null 2>&1; then
        exit 0
      fi
      kill -0 "$session_pid" 2>/dev/null || {
        echo "XFCE Wayland session 提前退出" >&2
        tail -80 "$log_file" >&2 2>/dev/null || true
        exit 1
      }
      i=$((i + 1))
      sleep 0.1
    done

    echo "XFCE Wayland session 启动超时" >&2
    tail -80 "$log_file" >&2 2>/dev/null || true
    exit 1
  ' || error "XFCE Wayland 会话启动失败"

  log "XFCE Wayland 桌面已启动"
}

start_rooted_newhome_desktop() {
  # server_noVNC is an rc3 frontend and may begin waiting for native :5900 as soon
  # as start_chroot runs. Bring up the canonical compositor stack immediately after.
  sync_remote_desktop_scripts
  disable_legacy_display_autostart
  start_chroot
  quiesce_legacy_chroot_display
  prepare_newhome_wayland_runtime
  start_newhome_wayland_acceptor
  start_newhome_compositor

  # NewHome owns speaker output; graphical startup remains independent if audio is unavailable.
  if ! chroot_exec -u root 'newhome-linux-cli audio status' 2>/dev/null | grep -q '"available": true'; then
    chroot_exec -u root 'newhome-linux-cli audio restart' >/dev/null 2>&1 ||
      log "NewHome audio unavailable (newhome-linux-cli audio status)"
  fi

  mount_newhome_x11_runtime
  wait_newhome_xwayland_ready
  start_xfce_wayland_session
  ensure_native_novnc_service
  wait_remote_desktop_services
}

stop_newhome_wayland_desktop() {
  chroot_exec -u root '
    pkill -TERM -x xfce4-session 2>/dev/null || true
    pkill -TERM -x xfce4-panel 2>/dev/null || true
    pkill -TERM -x xfdesktop 2>/dev/null || true
    pkill -TERM -x xfwm4 2>/dev/null || true
    pkill -TERM -f "^/usr/bin/newhome-wayland-acceptor /run/newhome-compositor/wayland-0 " 2>/dev/null || true
    # Do not let restart race the retiring acceptor. Only a real LISTEN entry counts;
    # connected sockets can keep the pathname visible after the listener is gone.
    i=0
    while [ "$i" -lt 50 ] && awk "\$4 == \"00010000\" && \$5 == \"0001\" && \$6 == \"01\" && \$8 == \"/run/newhome-compositor/wayland-0\" { found = 1; exit } END { exit(found ? 0 : 1) }" /proc/net/unix 2>/dev/null; do
      i=$((i + 1))
      sleep 0.05
    done
    pkill -KILL -f "^/usr/bin/newhome-wayland-acceptor /run/newhome-compositor/wayland-0 " 2>/dev/null || true
    rm -f /run/newhome-compositor/xfce-session.pid /run/newhome-compositor/wayland-acceptor.pid
    if ! awk "\$4 == \"00010000\" && \$5 == \"0001\" && \$6 == \"01\" && \$8 == \"/run/newhome-compositor/wayland-0\" { found = 1; exit } END { exit(found ? 0 : 1) }" /proc/net/unix 2>/dev/null; then
      rm -f /run/newhome-compositor/wayland-0
    fi
  ' >/dev/null 2>&1 || true
  if mountpoint -q "$DEBIAN_DIR/tmp/.X11-unix" 2>/dev/null; then
    sudo umount "$DEBIAN_DIR/tmp/.X11-unix" >/dev/null 2>&1 || true
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
  stop_newhome_wayland_desktop
  stop_newhome_compositor
  unmount_newhome_wayland_runtime
  stop_chroot_container 2>/dev/null || true

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
  stop_newhome_compositor
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
  if sudo /system/bin/dumpsys activity services com.example.customlauncher 2>/dev/null | grep -q 'LinuxDesktopFloatingService'; then
    echo "NewHome Smithay runtime service: running"
  else
    echo "NewHome Smithay runtime service: down"
  fi
  check_chroot_status
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
  enter_chroot_shell
}

# 在chroot中执行命令 (调用cli.sh中的函数)
exec_in_chroot() {
  if [ $# -eq 0 ]; then
    error "请提供要执行的命令"
  fi

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
  start         启动基础服务 + chroot Linux + NewHome compositor + XFCE Wayland
  stop          停止所有服务
  restart       重启所有服务
  status        查看 NewHome compositor + chroot 状态
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
  - termux_all_in_one.sh: 整体服务编排 (基础服务 + chroot + NewHome Wayland + XFCE)
  - cli.sh: 专业chroot容器管理 (挂载、进程、sysv、配置等)
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
      log "所有服务启动完成：chroot + NewHome Wayland + XFCE"
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
