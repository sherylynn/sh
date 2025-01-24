#!/bin/bash
#cp ./xstartup ~/.vnc/
#cp fcitx.desktop

# 检查 fcitx5 进程是否存在
if ! pgrep -x "fcitx5" >/dev/null; then
  echo "Starting fcitx5..."
  # 设置必要的环境变量（如 DBus）
  export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
  # 启动 fcitx5（后台运行）
  fcitx5 &
else
  echo "fcitx5 is already running."
fi
