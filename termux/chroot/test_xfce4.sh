#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# 社区标准启动脚本 - 最简版 (排除所有自定义逻辑干扰)
#
# 参考:
#   - termux-x11 官方 README (https://github.com/termux/termux-x11)
#   - LinuxDroidMaster/Termux-Desktops
#
# 用途: 验证 termux-x11 + proot debian + xfce4 基本链路是否正常
# 用法: bash ~/sh/termux/chroot/test_xfce4.sh
# 退出: Ctrl+C 或在 xfce4 里 logout
#
# 与 proot_all_in_one.sh 的区别:
#   - 不用 --isolated (用 proot-distro 默认行为, 容器内 pgrep 能看到 termux 进程)
#   - 不用 start_init / rc3.d (直接 proot-distro login)
#   - 复用容器内 server_noVNC.sh (xfce4 + x11vnc + novnc_proxy 一次拉起)
#   - 前台运行 (脚本阻塞在 server_noVNC.sh 的 novnc_proxy, 不后台 daemon)
# ============================================================

set -e

echo "========================================"
echo "  社区标准启动脚本 - termux-x11 + xfce4"
echo "========================================"
echo ""

# 0. 清理旧进程
echo "[1/8] 清理旧进程..."
killall -9 termux-x11 2>/dev/null || true
# 双重杀: pkill 直接杀进程 + am force-stop 通过 Android 系统停止
# pkill 在无 root 下可能杀不死 APP (不同 uid), am force-stop 补充
pkill -f com.termux.x11 2>/dev/null || true
am force-stop com.termux.x11 2>/dev/null || true
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 2>/dev/null || true
sleep 1

# 1. 清理 X socket 残留 (避免 "Server is already active for display 1")
echo "[2/8] 清理 X socket 残留..."
rm -f "${TMPDIR}/.X1-lock" 2>/dev/null || true
rm -rf "${TMPDIR}/.X11-unix/X1" 2>/dev/null || true

# 2. 设置环境变量
echo "[3/8] 设置环境变量..."
export XDG_RUNTIME_DIR="${TMPDIR}"

# 3. 启动 PulseAudio (音频, 对齐开源项目)
echo "[4/8] 启动 PulseAudio..."
pulseaudio --start \
  --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" \
  --exit-idle-time=-1 2>/dev/null || true

# 4. 启动 termux-x11 X server (后台运行)
#    注意: termux-x11 不会自动启动 Termux:X11 APP, 后面需要手动 am start
echo "[5/8] 启动 termux-x11 :1..."
termux-x11 :1 -ac +extension DPMS -dpi 100 >"${TMPDIR}/test_x11.log" 2>&1 &
X11_PID=$!

# 5. 等待 X server 稳定
echo "      等待 X server 稳定 (3秒)..."
sleep 3

# 检查 X server 是否还活着
if ! kill -0 "$X11_PID" 2>/dev/null; then
  echo "❌ termux-x11 启动失败! 日志内容:"
  echo "---"
  cat "${TMPDIR}/test_x11.log"
  echo "---"
  exit 1
fi
echo "      ✅ termux-x11 进程存活 (PID: $X11_PID)"

# 6. 启动 Termux:X11 APP (termux-x11 不会自动启动 APP, 必须手动 am start)
echo "[6/8] 启动 Termux:X11 APP..."
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
sleep 1

# 7. 获取 wake-lock (防止 Android 杀后台进程)
echo "[7/8] 获取 wake-lock..."
termux-wake-lock 2>/dev/null || true

# 7. 登录 proot 容器, 复用容器内 server_noVNC.sh 一次性拉起 noVNC 链路
#    server_noVNC.sh 在 termux-x11 分支会自动:
#      - 检测 termux-x11 → DISPLAY=:1 (与上面 termux-x11 :1 对齐)
#      - 启动 startxfce4   (后台)
#      - 启动 x11vnc       (后台, VNC 端口 5900, 需 ~/.vnc/passwd)
#      - 启动 novnc_proxy  (前台, 10086 端口, 阻塞 ← 脚本停在这里)
#    --shared-tmp: 让容器内 /tmp/.X11-unix/X1 可达 termux-x11 的 X socket
echo "[8/8] 登录 Debian 容器, 启动 server_noVNC.sh..."
echo "      (Ctrl+C 退出, 或在 xfce4 里注销)"
echo ""
echo "========================================"
echo "  Termux:X11 APP 应显示 xfce4 桌面"
echo "  VNC 客户端可连 <设备IP>:5900"
echo "  noVNC 浏览器访问: http://<设备IP>:10086"
echo "  日志: cat \$TMPDIR/test_x11.log"
echo "========================================"
echo ""

# 首次使用提示: server_noVNC.sh 需要容器内 ~/.vnc/passwd
# 不存在时会交互式提示输入密码 (termux 前台可输入)
# 提前创建: proot-distro login debian -- x11vnc -storepasswd <密码> ~/.vnc/passwd

proot-distro login debian --shared-tmp -- bash -c '
  set -e
  # 前置检查: server_noVNC.sh 是否存在
  if [ ! -f "$HOME/sh/win-git/server_noVNC.sh" ]; then
    echo "[容器内] ❌ 未找到 ~/sh/win-git/server_noVNC.sh"
    echo "[容器内] 请先在容器内运行: bash ~/sh/win-git/server_configure.sh"
    exit 1
  fi
  # 前置检查: noVNC 是否安装 (server_noVNC.sh 末尾会调用 novnc_proxy)
  if [ ! -x "$HOME/tools/noVNC/utils/novnc_proxy" ]; then
    echo "[容器内] ❌ 未找到 ~/tools/noVNC/utils/novnc_proxy"
    echo "[容器内] 请先在容器内运行: zsh ~/sh/win-git/noVNC.sh"
    exit 1
  fi
  # 前置检查: X socket 是否可达 (确认 --shared-tmp 生效 + termux-x11 已起)
  if [ ! -S "/tmp/.X11-unix/X1" ]; then
    echo "[容器内] ❌ /tmp/.X11-unix/X1 不可达"
    echo "[容器内] 检查 termux-x11 是否启动 / --shared-tmp 是否传入"
    exit 1
  fi
  echo "[容器内] ✅ 前置检查通过, 调用 server_noVNC.sh"
  echo ""
  # exec 替换进程, 让 server_noVNC.sh 直接接管信号 (Ctrl+C 能干净退出)
  exec bash "$HOME/sh/win-git/server_noVNC.sh"
'

# xfce4 退出后清理
echo ""
echo "xfce4 已退出, 清理进程..."
kill "$X11_PID" 2>/dev/null || true
# 双重杀: pkill 直接杀进程 + am force-stop 通过 Android 系统停止
# (与启动逻辑一致, pkill 在无 root 下可能杀不死 APP, am force-stop 补充)
pkill -f com.termux.x11 2>/dev/null || true
am force-stop com.termux.x11 2>/dev/null || true
am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 2>/dev/null || true
termux-wake-unlock 2>/dev/null || true
echo "完成"
