#!/bin/bash
set -euo pipefail

SCRIPT_NAME="xpra"
if [ "$(id -u)" -eq 0 ]; then
  export HOME=/root
fi

XPRA_PORT=${XPRA_PORT:-10087}
XPRA_HOST=${XPRA_HOST:-127.0.0.1}
XPRA_DISPLAY=${XPRA_DISPLAY:-:1}
XPRA_PASSWORD_FILE=${XPRA_PASSWORD_FILE:-$HOME/.xpra/newhome-password.txt}
XPRA_LOG_DIR=${XPRA_LOG_DIR:-$HOME/.xpra}
XPRA_LOG=${XPRA_LOG:-$XPRA_LOG_DIR/newhome-shadow.log}
XPRA_TLS_HELPER=${XPRA_TLS_HELPER:-$HOME/sh/win-git/noVNC_tls.sh}

mkdir -p "$XPRA_LOG_DIR"
chmod 700 "$XPRA_LOG_DIR"

command -v xpra >/dev/null 2>&1 || {
  echo "错误：找不到 xpra，请先运行 /root/sh/win-git/xpra.sh" >&2
  exit 1
}

if [ ! -s "$XPRA_PASSWORD_FILE" ]; then
  echo "错误：缺少 Xpra 密码文件：$XPRA_PASSWORD_FILE" >&2
  echo "请先运行 /root/sh/win-git/xpra.sh" >&2
  exit 1
fi
chmod 600 "$XPRA_PASSWORD_FILE" 2>/dev/null || true

# Reuse exactly the same NewHome local CA and leaf certificate as noVNC.
# Controllers that already trust novnc-ca.crt therefore trust Xpra too.
if [ ! -r "$XPRA_TLS_HELPER" ]; then
  echo "错误：找不到 noVNC TLS helper：$XPRA_TLS_HELPER" >&2
  exit 1
fi
# shellcheck source=/dev/null
. "$XPRA_TLS_HELPER"
novnc_tls_prepare || {
  echo "错误：无法准备 NewHome/noVNC TLS 证书" >&2
  exit 1
}
XPRA_TLS_CERT=${XPRA_TLS_CERT:-$NOVNC_TLS_CERT}
XPRA_TLS_KEY=${XPRA_TLS_KEY:-$NOVNC_TLS_KEY}
[ -s "$XPRA_TLS_CERT" ] && [ -s "$XPRA_TLS_KEY" ] || {
  echo "错误：Xpra TLS 证书或私钥不存在" >&2
  exit 1
}

# Keep the same rendering/input environment as server_noVNC.sh.
export GTK_IM_MODULE="fcitx"
export QT_IM_MODULE="fcitx"
export XMODIFIERS="@im=fcitx"

if [ -f "/sdcard/Download/使用虚拟显卡.txt" ]; then
  export GALLIUM_DRIVER=virpipe
  export MESA_GL_VERSION_OVERRIDE=4.0
elif lscpu 2>/dev/null | grep -q "Oryon"; then
  export MESA_LOADER_DRIVER_OVERRIDE=kgsl
  export TU_DEBUG=noconform
elif pgrep -f "virgl_test" >/dev/null 2>&1; then
  export GALLIUM_DRIVER=virpipe
  export MESA_GL_VERSION_OVERRIDE=4.0
fi

export DISPLAY="$XPRA_DISPLAY"
export XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}
export PULSE_SERVER=${PULSE_SERVER:-tcp:127.0.0.1:4713}

# Xpra shadow shares the existing Termux:X11 desktop. It must not create a
# second Xvfb/Xdummy desktop, otherwise it would no longer be a drop-in remote
# path for the current XFCE session.
if [ ! -S "/tmp/.X11-unix/X${XPRA_DISPLAY#:}" ]; then
  echo "错误：找不到 Termux:X11 socket /tmp/.X11-unix/X${XPRA_DISPLAY#:}" >&2
  echo "请先启动 Termux:X11，再启动 Xpra。" >&2
  exit 1
fi

# server_noVNC.sh also owns the responsibility of ensuring XFCE is up. Do the
# same here so init_d_xpra.sh can replace init_d_noVNC.sh during A/B testing.
if [ -x "$HOME/sh/termux/newhome_mic_bridge.sh" ]; then
  "$HOME/sh/termux/newhome_mic_bridge.sh" start >/tmp/newhome-mic-xpra-start.log 2>&1 || true
fi

if ! pgrep -f 'xfce4-session|startxfce4' >/dev/null 2>&1; then
  echo "启动 XFCE4 on $DISPLAY"
  nohup dbus-launch --exit-with-session startxfce4 </dev/null >>"$XPRA_LOG_DIR/xfce4.log" 2>&1 &
  sleep 2
fi

XPRA_VERSION=$(xpra --version 2>/dev/null | head -1 || true)
XPRA_MAJOR=$(printf '%s\n' "$XPRA_VERSION" | sed -n 's/.*v\([0-9][0-9]*\).*/\1/p' | head -1)
XPRA_MINOR=$(printf '%s\n' "$XPRA_VERSION" | sed -n 's/.*v[0-9][0-9]*\.\([0-9][0-9]*\).*/\1/p' | head -1)
[ -n "$XPRA_MAJOR" ] || XPRA_MAJOR=0
[ -n "$XPRA_MINOR" ] || XPRA_MINOR=0

BIND="${XPRA_HOST}:${XPRA_PORT}"
COMMON_ARGS=(
  shadow "$XPRA_DISPLAY"
  --html=on
  --daemon=no
  --mdns=no
  --sharing=yes
  "--ssl-cert=${XPRA_TLS_CERT}"
  "--ssl-key=${XPRA_TLS_KEY}"
)

# Xpra 6.5 introduced the unambiguous auth=MODULE(option=value) socket syntax.
# Keep a legacy branch so the script still works if installation falls back to
# Debian Bookworm's old Xpra 3.x package or another pre-6.5 build.
if [ "$XPRA_MAJOR" -gt 6 ] || { [ "$XPRA_MAJOR" -eq 6 ] && [ "$XPRA_MINOR" -ge 5 ]; }; then
  AUTH_BIND="${BIND},auth=file(filename=${XPRA_PASSWORD_FILE})"
  COMMON_ARGS+=("--bind-ssl=${AUTH_BIND}")
else
  COMMON_ARGS+=(
    "--bind-ssl=${BIND}"
    --ssl-auth=file
    "--password-file=${XPRA_PASSWORD_FILE}"
  )
fi

# Stop only the previous NewHome Xpra shadow session if it is still present.
if [ -s "$XPRA_LOG_DIR/newhome-shadow.pid" ]; then
  old_pid=$(cat "$XPRA_LOG_DIR/newhome-shadow.pid" 2>/dev/null || true)
  case "$old_pid" in
    *[!0-9]*|'') ;;
    *)
      if [ -r "/proc/$old_pid/cmdline" ] && tr '\0' ' ' <"/proc/$old_pid/cmdline" | grep -q '[x]pra.*shadow'; then
        kill -TERM "$old_pid" 2>/dev/null || true
        sleep 1
      fi
      ;;
  esac
fi

printf '%s\n' "$$" >"$XPRA_LOG_DIR/newhome-shadow.pid"
trap 'rm -f "$XPRA_LOG_DIR/newhome-shadow.pid"' EXIT INT TERM

echo "Xpra: $XPRA_VERSION"
echo "共享显示：$XPRA_DISPLAY"
echo "HTML5 HTTPS: https://127.0.0.1:${XPRA_PORT}/"
echo "监听：$BIND (TLS only)"
echo "复用 noVNC CA：$NOVNC_TLS_CA_CERT"
echo "TLS 证书：$XPRA_TLS_CERT"
echo "日志：$XPRA_LOG"

# Keep this process in the foreground. init_d_xpra.sh is responsible for
# detaching it with setsid/nohup, exactly like init_d_noVNC.sh.
xpra "${COMMON_ARGS[@]}" 2>&1 | tee -a "$XPRA_LOG"
