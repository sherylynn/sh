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

# NewHome compositor owns display, clipboard, resize and RFB. noVNC only supplies
# the browser HTTPS/WebSocket frontend.

# Preserve the existing Mesa/virgl environment selection used by Linux clients; it no
# longer selects a VNC/display backend.
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
NEWHOME_RFB_BACKEND=native
NOVNC_VNC_TARGET=127.0.0.1:5900
NOVNC_BACKEND_STATE="$HOME/.vnc/novnc-backend.env"

native_rfb_probe_host() {
  local host=$1
  timeout 1 bash -c "exec 3<>/dev/tcp/${host}/5900" >/dev/null 2>&1
}

native_rfb_select_target() {
  local host
  # Android app and chroot may be in distinct network namespaces. Probe loopback first,
  # then only this device's own IPv4 interface addresses. The native RFB server rejects
  # non-self peers before the RFB handshake, so this does not expose unauthenticated RFB.
  for host in 127.0.0.1 $(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+(\.[0-9]+){3}$' | sort -u); do
    if native_rfb_probe_host "$host"; then
      NOVNC_VNC_TARGET=${host}:5900
      return 0
    fi
  done
  return 1
}

# NewHome native Wayland compositor 是唯一桌面 owner。XWayland 仅由 compositor
# 内部按需提供给旧 X11 客户端；noVNC 永远只绑定 native RFB。
mkdir -p "$HOME/.vnc"

# noVNC 只是浏览器 WebSocket frontend，不再启动第二套显示服务器。
echo "使用 NewHome compositor native RFB backend"
for _native_rfb_wait in $(seq 1 30); do
  if native_rfb_select_target; then
    echo "NewHome native RFB 已在 ${NOVNC_VNC_TARGET} 就绪"
    break
  fi
  sleep 0.5
done
native_rfb_select_target || {
  echo "错误：NewHome native compositor RFB :5900 未就绪" >&2
  echo "XWayland 仅用于旧 X11 应用兼容，不是远程桌面 framebuffer owner" >&2
  exit 1
}
printf 'backend=native
target=%s
' "$NOVNC_VNC_TARGET" >"$NOVNC_BACKEND_STATE"

# noVNC 只是 NewHome native RFB 的浏览器 WebSocket frontend。
# 不启动第二套 X11/Wayland/VNC server。
file_path="./tools/noVNC/utils/novnc_proxy"
NOVNC_LOG="$HOME/.vnc/novnc-proxy.log"
NOVNC_PID_FILE="$HOME/.vnc/novnc-proxy.pid"

if [ ! -x "$file_path" ]; then
  echo "错误：找不到可执行的 noVNC 启动器：$file_path"
  exit 1
fi

# rc3 services are launched asynchronously by termux_all_in_one.sh. Keep
# websockify in its own session so the browser frontend survives the short-lived
# NewHome/Termux restart control pipe.
if pgrep -f '^python3 /root/tools/noVNC/utils/newhome_websockify.py .*10086 .*:5900' >/dev/null 2>&1; then
  echo "noVNC 已经在 10086 端口运行"
else
  echo "启动 noVNC HTTPS/WebSocket 服务..."
  NOVNC_CREDENTIAL_FILE=/root/.vnc/novnc.credentials
  NOVNC_USER=$(sed -n 's/^username=//p' "$NOVNC_CREDENTIAL_FILE" | head -1)
  NOVNC_PASSWORD=$(sed -n 's/^password=//p' "$NOVNC_CREDENTIAL_FILE" | head -1)
  [ -n "$NOVNC_USER" ] && [ -n "$NOVNC_PASSWORD" ] || {
    echo "错误：noVNC 登录凭据不存在或格式错误：$NOVNC_CREDENTIAL_FILE" >&2
    exit 1
  }
  nohup setsid "$file_path" --vnc "$NOVNC_VNC_TARGET" --listen 10086 \
    --web-auth --auth-plugin BasicHTTPAuth \
    --auth-source "$NOVNC_USER:$NOVNC_PASSWORD" \
    </dev/null >>"$NOVNC_LOG" 2>&1 &
  NOVNC_PID=$!
  printf '%s\n' "$NOVNC_PID" >"$NOVNC_PID_FILE"

  for _novnc_wait in 1 2 3 4 5; do
    if pgrep -f '^python3 /root/tools/noVNC/utils/newhome_websockify.py .*10086 .*:5900' >/dev/null 2>&1; then
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
