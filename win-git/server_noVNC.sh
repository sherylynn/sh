#!/bin/bash
SCRIPT_NAME="noVNC"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# SysV/rc3 启动时 HOME 可能继承为 /；本服务始终以 root 运行，固定运行目录，
# 避免日志、PID 和认证文件被写到错误位置。
if [ "$(id -u)" -eq 0 ]; then
  export HOME=/root
fi
realpath() {
  local x=$1
  echo $(
    cd $(dirname $0)
    pwd
  )/$x

}
realpathdir() {
  local x=$1
  echo $(
    cd $(dirname $0)
    pwd
  )

}
cd $(realpathdir ./server_${SCRIPT_NAME}.sh)
pwd
#load env
test -f ../../tools/rc/${SCRIPT_NAME}rc && . ../../tools/rc/${SCRIPT_NAME}rc

echo $(whoami)
# login need systemd user root
#novnc -p 3000 -t fontSize=18 login
# login need systemd user $(whoami)

start_xrdp_chansrv() {
  local display="${1:-:1}"
  local chansrv_bin=/usr/sbin/xrdp-chansrv
  local chansrv_pid_file="$HOME/.vnc/xrdp-chansrv.pid"
  local chansrv_log="$HOME/.vnc/xrdp-chansrv-start.log"
  local old_pid="" old_display=""

  [ -x "$chansrv_bin" ] || {
    echo "xrdp-chansrv 未安装；请重新运行 $HOME/sh/win-git/noVNC.sh" >&2
    return 1
  }

  if [ -s "$chansrv_pid_file" ]; then
    old_pid=$(cat "$chansrv_pid_file" 2>/dev/null || true)
    if [ -n "$old_pid" ] && [ -r "/proc/$old_pid/cmdline" ] &&
       tr '\0' ' ' <"/proc/$old_pid/cmdline" | grep -Fq '/usr/sbin/xrdp-chansrv'; then
      old_display=$(tr '\0' '\n' <"/proc/$old_pid/environ" 2>/dev/null |
        sed -n 's/^DISPLAY=//p' | head -1)
      if [ "$old_display" = "$display" ]; then
        echo "xrdp-chansrv 已在 $display 上运行（PID $old_pid）"
        return 0
      fi
      kill -TERM "$old_pid" 2>/dev/null || true
      sleep 1
    fi
  fi

  # Debian 的 /usr/share/xrdp/socksetup 通常由 /etc/init.d/xrdp 调用。
  # 我们刻意禁用了发行版 xrdp service，并由本脚本直接启动 xrdp，
  # 因此必须在启动 chansrv 前自行创建这个目录。缺少它时 chansrv
  # 进程仍会存活，但不会创建 xrdp_chansrv_socket_N，xrdp 最终会
  # xrdp_mm_chansrv_connect timeout，表现就是双向剪贴板完全失效。
  if [ -r /usr/share/xrdp/socksetup ]; then
    # shellcheck disable=SC1091
    . /usr/share/xrdp/socksetup || return 1
  else
    mkdir -p /run/xrdp/sockdir || return 1
    chmod 3777 /run/xrdp/sockdir || return 1
  fi
  # xrdp 0.10.x 把每个用户的 chansrv socket 放在 UID 子目录中。
  # sesman 正常启动会创建它；我们是手工共享现有 DISPLAY，所以也要补上。
  local chansrv_uid
  chansrv_uid=$(id -u)
  mkdir -p "/run/xrdp/sockdir/$chansrv_uid" || return 1
  chown "$chansrv_uid:$(id -g)" "/run/xrdp/sockdir/$chansrv_uid" 2>/dev/null || true
  chmod 700 "/run/xrdp/sockdir/$chansrv_uid" || return 1

  # 本项目只维护一个共享 XFCE/X11 桌面。清理没有被 PID 文件记录的旧
  # chansrv，避免它继续占用上一轮 DISPLAY 的 channel socket。
  pkill -TERM -x xrdp-chansrv >/dev/null 2>&1 || true
  sleep 0.5
  mkdir -p "$HOME/.vnc" "$HOME/.local/share/xrdp"
  nohup setsid env DISPLAY="$display" XAUTHORITY="$HOME/.Xauthority" HOME="$HOME" \
    "$chansrv_bin" </dev/null >>"$chansrv_log" 2>&1 &
  printf '%s\n' "$!" >"$chansrv_pid_file"

  local wait_step
  for wait_step in 1 2 3 4 5 6; do
    if kill -0 "$!" 2>/dev/null; then
      sleep 0.25
      if kill -0 "$!" 2>/dev/null; then
        local chansrv_socket="/run/xrdp/sockdir/$(id -u)/xrdp_chansrv_socket_${display#:}"
        if [ -S "$chansrv_socket" ]; then
          echo "xrdp-chansrv 已绑定 $display，用于 Unicode cliprdr/X11 剪贴板"
          return 0
        fi
      fi
    fi
    sleep 0.25
  done

  echo "xrdp-chansrv 启动失败，最近日志：" >&2
  tail -40 "$chansrv_log" >&2
  return 1
}

start_xrdp_vnc_proxy() {
  local display="${1:-:1}"
  local display_number="${display#:}"
  local xrdp_bin=/usr/sbin/xrdp
  local xrdp_config=/etc/xrdp/newhome-x11.ini
  local xrdp_pid_file="$HOME/.vnc/xrdp.pid"
  local xrdp_runtime_pid_file=/run/xrdp/xrdp.pid
  local xrdp_log="$HOME/.vnc/xrdp-newhome.log"
  local old_pid="" runtime_pid=""

  [ -x "$xrdp_bin" ] || {
    echo "XRDP 未安装；请重新运行 $HOME/sh/win-git/noVNC.sh" >&2
    return 1
  }
  # xrdp 的 VNC proxy 自带 clipboard 只按经典 RFB/ISO-8859-1 处理。
  # 对已有 X11 桌面，Unicode 路径是单独启动 xrdp-chansrv，并让连接项
  # 直接连接它创建的 Unix socket。不能依赖 DISPLAY(n) 推导 UID；在
  # Debian xrdp 0.10.1 的外部 VNC 会话中它会连错/超时。
  start_xrdp_chansrv "$display" || return 1
  XRDP_DISPLAY_NUMBER="$display_number" XRDP_SESSION_UID="$(id -u)" \
    /bin/bash "$HOME/sh/win-git/configure_xrdp_vnc_proxy.sh"

  if [ -s "$xrdp_pid_file" ]; then
    old_pid=$(cat "$xrdp_pid_file" 2>/dev/null || true)
    if [ -n "$old_pid" ] && [ -r "/proc/$old_pid/cmdline" ] &&
       tr '\0' ' ' <"/proc/$old_pid/cmdline" | grep -Fq "$xrdp_config"; then
      echo "XRDP 已经在 3389 端口运行"
      return 0
    fi
  fi

  pkill -TERM -x xrdp >/dev/null 2>&1 || true
  sleep 1
  # xrdp refuses to start when its global runtime PID file is stale. Never
  # remove it while it still names a live xrdp process.
  if [ -s "$xrdp_runtime_pid_file" ]; then
    runtime_pid=$(cat "$xrdp_runtime_pid_file" 2>/dev/null || true)
    if [ -z "$runtime_pid" ] || [ ! -r "/proc/$runtime_pid/cmdline" ] ||
       ! tr '\0' ' ' <"/proc/$runtime_pid/cmdline" | grep -Fq '/usr/sbin/xrdp'; then
      rm -f "$xrdp_runtime_pid_file"
    fi
  fi
  mkdir -p /run/xrdp
  nohup setsid "$xrdp_bin" --nodaemon --config "$xrdp_config" \
    </dev/null >>"$xrdp_log" 2>&1 &
  printf '%s\n' "$!" >"$xrdp_pid_file"

  local wait_step
  for wait_step in 1 2 3 4 5 6 7 8 9 10; do
    if grep -qE ':0D3D .* 0A ' /proc/net/tcp /proc/net/tcp6 2>/dev/null; then
      echo "XRDP 已在 3389 端口启动，代理现有 X11 桌面"
      return 0
    fi
    sleep 0.5
  done
  echo "XRDP 启动失败，最近日志：" >&2
  tail -40 "$xrdp_log" >&2
  return 1
}

#virgl
#这个需要关掉noVNC的特效的
#if [ -f "$MESA_FREE_SO" ]; then
#检测是否强制使用虚拟显卡
if [ -f "/sdcard/Download/使用虚拟显卡.txt" ]; then
  echo "检测到强制使用虚拟显卡文件，使用virgl服务"
  export GTK_IM_MODULE="fcitx"
  export QT_IM_MODULE="fcitx"
  export XMODIFIERS="@im=fcitx"
  export GALLIUM_DRIVER=virpipe
  export MESA_GL_VERSION_OVERRIDE=4.0
elif lscpu | grep -q "Oryon"; then
  echo '启动mesa的noVNC'
  export GTK_IM_MODULE="fcitx"
  export QT_IM_MODULE="fcitx"
  export XMODIFIERS="@im=fcitx"
  export MESA_LOADER_DRIVER_OVERRIDE=kgsl
  export TU_DEBUG=noconform
  #关闭xfce4的特效合成器，因为和freedreno驱动不兼容
  #export XFWM4_COMPOSITOR=0 这个命令是错的
  #~/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml 需要进这里，修改找到包含 use_compositing 的行。
  #将其值从 true 改为 false

  # 脚本作用：在 XFCE 窗口管理器 (xfwm4) 的配置文件中禁用窗口合成特效。
  # 它通过将 use_compositing 的值从 "true" 修改为 "false" 来实现。

  # 配置文件路径
  CONFIG_FILE="../../.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"

  # 检查文件是否存在，并且只在存在时才执行操作
  if [ -f "$CONFIG_FILE" ]; then
    # 使用 sed 命令进行原地替换。
    # 该命令会查找包含 '<property name="use_compositing"' 的行，
    # 然后将该行中的 value="true" 替换为 value="false"。
    sed -i '/<property name="use_compositing"/s/value="true"/value="false"/' "$CONFIG_FILE"

    echo "操作完成。use_compositing 的值已被设置为 false。"
    echo "您可能需要重启 XFCE 会话或窗口管理器以使更改生效。"
  else
    # 如果文件不存在，则打印提示信息并正常退出。
    echo "配置文件 $CONFIG_FILE 未找到，不执行任何操作。"
  fi
elif pgrep -f "virgl_test" >/dev/null; then
  #默认就用自带的virgl_test吧避免xfce4启动不了
  #if pgrep -f "virgl_test" >/dev/null; then
  #export DISPLAY=:0
  echo '启动virgl的noVNC'
  export GTK_IM_MODULE="fcitx"
  export QT_IM_MODULE="fcitx"
  export XMODIFIERS="@im=fcitx"
  export GALLIUM_DRIVER=virpipe
  export MESA_GL_VERSION_OVERRIDE=4.0
  #尝试解决glx错误 #并无效果，放弃
  #export vblank_mode=0
fi

#x11
DISPLAY_PORT=0
cd ../../
DroidSpaces_path="/run/droidspaces/container.config"


# 检测 termux-x11 是否在运行
# chroot: pgrep 可见宿主机进程 (com.termux.x11)
# proot --isolated: pgrep 看不到 termux 进程, 改用 X socket 文件检测
#   termux-x11 :1 创建 $TMPDIR/.X11-unix/X1, --shared-tmp 让容器内 /tmp/.X11-unix/X1 可达
# Anland/Labwc 是 rootless Wayland。x11vnc 无法抓取它的 Xwayland 根窗口，
# 必须优先用 wayvnc；不能让残留的 X1 socket 把 profile 误判成 Termux:X11。
if pgrep -x labwc >/dev/null && [ -S /run/user/0/wayland-0 ]; then
  echo "检测到 Anland/Labwc，启动 wayvnc"
  WAYVNC_CONFIG=/root/.config/wayvnc/config
  [ -s "$WAYVNC_CONFIG" ] || /bin/bash /root/sh/win-git/configure_wayvnc.sh
  pkill -x x11vnc >/dev/null 2>&1 || true
  pkill -x wayvnc >/dev/null 2>&1 || true
  export XDG_RUNTIME_DIR=/run/user/0
  export WAYLAND_DISPLAY=wayland-0
  WAYVNC_RESIZE_HOOK=/root/.local/lib/wayvnc_anland_resize.so
  [ -s "$WAYVNC_RESIZE_HOOK" ] || /bin/bash /root/sh/win-git/build_wayvnc_anland_resize.sh
  nohup setsid env LD_PRELOAD="$WAYVNC_RESIZE_HOOK" \
    NEWHOME_ANLAND_RESIZE_SCRIPT=/root/sh/termux/chroot/wayland/anland_remote_resize_queue.sh \
    wayvnc -C "$WAYVNC_CONFIG" -r \
    </dev/null >>/root/.vnc/wayvnc.log 2>&1 &
  for _wayvnc_wait in 1 2 3 4 5; do
    if pgrep -x wayvnc >/dev/null 2>&1; then
      echo "wayvnc 已在 127.0.0.1:5900 启动"
      break
    fi
    sleep 1
  done
  pgrep -x wayvnc >/dev/null 2>&1 || {
    echo "wayvnc 启动失败，最近日志：" >&2
    tail -40 /root/.vnc/wayvnc.log >&2
    exit 1
  }
elif pgrep -f "com.termux.x11" >/dev/null; then
  DISPLAY_PORT=1
  export DISPLAY=:${DISPLAY_PORT}
  export PULSE_SERVER=tcp:127.0.0.1:4713
  # Ayatana rejects several Electron StatusNotifier items. Keep it out of the
  # X11/XFCE session so xfce4-panel's systray owns the watcher directly.
  bash "$HOME/sh/win-git/disable_ayatana_xfce_autostart.sh"
  ~/sh/termux/newhome_mic_bridge.sh start >/tmp/newhome-mic-xfce-start.log 2>&1 || true
  #当文件本身是bash启动的时候，这里用source就无效，但是本身是zsh启动的时候，再用zsh就无效
  #source  ~/tools/rc/allToolsrc
  # SysV/nohup 服务没有交互终端，加载 zplug 会阻塞并产生 broken pipe。
  if [ -t 0 ] && [ -f "$HOME/tools/rc/allToolsrc" ]; then
    zsh "$HOME/tools/rc/allToolsrc"
  fi
  dbus-launch --exit-with-session startxfce4 &
  # 配置项
  VNC_PASSWD_FILE="$HOME/.vnc/passwd"
  VNC_PORT=5900
  VNC_DISPLAY=:${DISPLAY_PORT}
  X11VNC_CMD="/usr/bin/x11vnc"
  LOG_FILE="$HOME/.vnc/x11vnc.log"

  # 创建 .vnc 目录
  mkdir -p "$(dirname "$VNC_PASSWD_FILE")"

  # 检查并生成密码文件
  if [ ! -f "$VNC_PASSWD_FILE" ]; then
    # 后台服务不能 read /dev/null；优先复用 server_configure 已写入的
    # wayvnc 密码，使 X11/Wayland 两条 noVNC 路线保持同一凭据。
    vnc_password=$(sed -n 's/^[[:space:]]*password[[:space:]]*=[[:space:]]*//p' \
      "$HOME/.config/wayvnc/config" 2>/dev/null | head -1)
    if [ -z "$vnc_password" ]; then
      echo "错误：未找到 $VNC_PASSWD_FILE，wayvnc 配置中也没有可复用密码" >&2
      echo "请先运行 server_configure.sh 配置 VNC 凭据" >&2
      exit 1
    fi

    if ! $X11VNC_CMD -storepasswd "$vnc_password" "$VNC_PASSWD_FILE"; then
      echo "错误：密码文件生成失败！"
      exit 1
    fi
    chmod 600 "$VNC_PASSWD_FILE"
    echo "密码文件已创建: $VNC_PASSWD_FILE"
  fi
  #x11vnc -display :1 -rfbport 5900 -passwd yourpasswd -forever --noshm
  # 终止已有进程
  if pgrep -x "x11vnc" >/dev/null; then
    echo "停止正在运行的 x11vnc..."
    pkill x11vnc
    sleep 2
  fi

  # 启动服务
  echo "启动 x11vnc 服务..."
  nohup setsid env LD_PRELOAD="$HOME/.local/lib/x11vnc_remote_resize.so" $X11VNC_CMD \
    -display "$VNC_DISPLAY" \
    -auth "$HOME/.Xauthority" \
    -rfbauth "$VNC_PASSWD_FILE" \
    -rfbport "$VNC_PORT" \
    -forever \
    -noshm \
    -shared \
    -noxdamage \
    -cursor most \
    -nowf \
    -noscr \
    -xrandr resize \
    -reopen \
    -loop500 \
    -o "$LOG_FILE" </dev/null >/dev/null 2>&1 &
  #-nodpms \

  # 验证启动状态
  sleep 2
  if pgrep -x "x11vnc" >/dev/null; then
    echo "x11vnc 已成功启动！"
    echo "连接命令: vncviewer your_server_ip:$VNC_PORT"
    start_xrdp_vnc_proxy "$VNC_DISPLAY" || exit 1
  else
    echo "错误：x11vnc 启动失败，请检查日志: $LOG_FILE"
    exit 1
  fi

elif [ -e "$DroidSpaces_path" ]; then
  DISPLAY_PORT=5
  export DISPLAY=:${DISPLAY_PORT}
  bash "$HOME/sh/win-git/disable_ayatana_xfce_autostart.sh"

  # 参照 xfce-start: 读取 container.config，若宿主启用 pulseaudio 则通过 unix socket 连接
  if grep -q 'enable_pulseaudio=1' "$DroidSpaces_path" 2>/dev/null; then
    : "${PULSE_SERVER:=unix:/tmp/.pulse-socket}"
    export PULSE_SERVER
  fi

  #droidspaces中不需要手动启动xfce4以及加载环境变量
  #当文件本身是bash启动的时候，这里用source就无效，但是本身是zsh启动的时候，再用zsh就无效
  #source  ~/tools/rc/allToolsrc
  if [ -t 0 ] && [ -f "$HOME/tools/rc/allToolsrc" ]; then
    zsh "$HOME/tools/rc/allToolsrc"
  fi
  pgrep -xf "startxfce4" >/dev/null || dbus-launch --exit-with-session startxfce4 &
  # 配置项
  VNC_PASSWD_FILE="$HOME/.vnc/passwd"
  VNC_PORT=5900
  VNC_DISPLAY=:${DISPLAY_PORT}
  X11VNC_CMD="/usr/bin/x11vnc"
  LOG_FILE="$HOME/.vnc/x11vnc.log"

  # 创建 .vnc 目录
  mkdir -p "$(dirname "$VNC_PASSWD_FILE")"

  # 检查并生成密码文件
  if [ ! -f "$VNC_PASSWD_FILE" ]; then
    echo "未找到 VNC 密码文件，正在创建..."
    read -s -p "输入 VNC 密码: " vnc_password
    echo
    read -s -p "再次确认密码: " vnc_password_confirm
    echo

    if [ "$vnc_password" != "$vnc_password_confirm" ]; then
      echo "错误：两次输入的密码不一致！"
      exit 1
    fi

    if ! $X11VNC_CMD -storepasswd "$vnc_password" "$VNC_PASSWD_FILE"; then
      echo "错误：密码文件生成失败！"
      exit 1
    fi
    chmod 600 "$VNC_PASSWD_FILE"
    echo "密码文件已创建: $VNC_PASSWD_FILE"
  fi
  #x11vnc -display :1 -rfbport 5900 -passwd yourpasswd -forever --noshm
  # 终止已有进程
  if pgrep -x "x11vnc" >/dev/null; then
    echo "停止正在运行的 x11vnc..."
    pkill x11vnc
    sleep 2
  fi

  # 启动服务
  echo "启动 x11vnc 服务..."
  env LD_PRELOAD="$HOME/.local/lib/x11vnc_remote_resize.so" $X11VNC_CMD \
    -display "$VNC_DISPLAY" \
    -auth "$HOME/.Xauthority" \
    -rfbauth "$VNC_PASSWD_FILE" \
    -rfbport "$VNC_PORT" \
    -forever \
    -noshm \
    -shared \
    -cursor most \
    -xrandr resize \
    -reopen \
    -loop500 \
    -o "$LOG_FILE" &
  #-nodpms \

  # 验证启动状态
  sleep 2
  if pgrep -x "x11vnc" >/dev/null; then
    echo "x11vnc 已成功启动！"
    echo "连接命令: vncviewer your_server_ip:$VNC_PORT"
    start_xrdp_vnc_proxy "$VNC_DISPLAY" || exit 1
  else
    echo "错误：x11vnc 启动失败，请检查日志: $LOG_FILE"
    exit 1
  fi
else
  export PULSE_SERVER=127.0.0.1
  vncserver -kill :${DISPLAY_PORT}
  rm -rf /tmp/.X*
  rm -rf /tmp/.x*
  vncserver -geometry 1920x966 -localhost no :${DISPLAY_PORT}
fi
file_path="./tools/noVNC/utils/novnc_proxy"
NOVNC_LOG="$HOME/.vnc/novnc-proxy.log"
NOVNC_PID_FILE="$HOME/.vnc/novnc-proxy.pid"

if [ ! -x "$file_path" ]; then
  echo "错误：找不到可执行的 noVNC 启动器：$file_path"
  exit 1
fi

# rc3 services are launched asynchronously by termux_all_in_one.sh. Keeping
# novnc_proxy in the foreground makes it inherit the short-lived NewHome
# restart pipe; when that pipe closes websockify exits, while detached x11vnc
# remains alive. Give noVNC its own session and log so it survives the launcher.
if pgrep -f '^python3 /root/tools/noVNC/utils/newhome_websockify.py .*10086 127\.0\.0\.1:5900' >/dev/null 2>&1; then
  echo "noVNC 已经在 10086 端口运行"
else
  echo "启动 noVNC HTTPS/WebSocket 服务..."
  NOVNC_CREDENTIAL_FILE=/root/.vnc/wayvnc.credentials
  NOVNC_USER=$(sed -n 's/^username=//p' "$NOVNC_CREDENTIAL_FILE" | head -1)
  NOVNC_PASSWORD=$(sed -n 's/^password=//p' "$NOVNC_CREDENTIAL_FILE" | head -1)
  [ -n "$NOVNC_USER" ] && [ -n "$NOVNC_PASSWORD" ] || {
    echo "错误：noVNC 登录凭据不存在或格式错误：$NOVNC_CREDENTIAL_FILE" >&2
    exit 1
  }
  nohup setsid "$file_path" --vnc 127.0.0.1:5900 --listen 10086 \
    --web-auth --auth-plugin BasicHTTPAuth \
    --auth-source "$NOVNC_USER:$NOVNC_PASSWORD" \
    </dev/null >>"$NOVNC_LOG" 2>&1 &
  NOVNC_PID=$!
  printf '%s\n' "$NOVNC_PID" >"$NOVNC_PID_FILE"

  for _novnc_wait in 1 2 3 4 5; do
    if pgrep -f '^python3 /root/tools/noVNC/utils/newhome_websockify.py .*10086 127\.0\.0\.1:5900' >/dev/null 2>&1; then
      echo "noVNC 已成功启动：https://127.0.0.1:10086/vnc.html"
      exit 0
    fi
    sleep 1
  done

  echo "错误：noVNC 未能启动，最近日志如下：" >&2
  tail -40 "$NOVNC_LOG" >&2
  exit 1
fi
#./utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10086
#su $(whoami) -c 'novnc -p 3000 -t fontSize=18 ssh localhost'
