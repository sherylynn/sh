#!/bin/bash
SCRIPT_NAME="noVNC"
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

#virgl
if pgrep -f "virgl_test" >/dev/null; then
  #export DISPLAY=:0
  export PULSE_SERVER=127.0.0.1
  export GTK_IM_MODULE="fcitx"
  export QT_IM_MODULE="fcitx"
  export XMODIFIERS="@im=fcitx"
  export GALLIUM_DRIVER=virpipe
  export MESA_GL_VERSION_OVERRIDE=4.0
  #尝试解决glx错误
  export vblank_mode=0
fi

#x11
DISPLAY_PORT=0
cd ../../
if pgrep -f "com.termux.x11" >/dev/null; then
  DISPLAY_PORT=1
  export DISPLAY=:${DISPLAY_PORT}
  #当文件本身是bash启动的时候，这里用source就无效，但是本身是zsh启动的时候，再用zsh就无效
  #source  ~/tools/rc/allToolsrc
  zsh ~/tools/rc/allToolsrc
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
  $X11VNC_CMD \
    -display "$VNC_DISPLAY" \
    -auth "$HOME/.Xauthority" \
    -rfbauth "$VNC_PASSWD_FILE" \
    -rfbport "$VNC_PORT" \
    -noshm \
    -nodpms \
    -forever \
    -shared \
    -o "$LOG_FILE" &

  # 验证启动状态
  sleep 2
  if pgrep -x "x11vnc" >/dev/null; then
    echo "x11vnc 已成功启动！"
    echo "连接命令: vncviewer your_server_ip:$VNC_PORT"
  else
    echo "错误：x11vnc 启动失败，请检查日志: $LOG_FILE"
    exit 1
  fi

else
  vncserver -kill :${DISPLAY_PORT}
  rm -rf /tmp/.X*
  rm -rf /tmp/.x*
  vncserver -geometry 1920x966 -localhost no :${DISPLAY_PORT}
fi
file_path="./tools/noVNC/utils/novnc_proxy"
if [ -e "$file_path" ]; then
  ./tools/noVNC/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10086
  #./tools/noVNC/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10000
else
  cd .
  #./tools/noVNC/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10000
  ./tools/noVNC/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10086
fi
#./utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 10086
#su $(whoami) -c 'novnc -p 3000 -t fontSize=18 ssh localhost'
