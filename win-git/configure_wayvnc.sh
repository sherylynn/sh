#!/bin/bash
# 为 Anland/Labwc 创建可重复部署的 wayvnc 认证配置。
set -euo pipefail

CONFIG_DIR=${WAYVNC_CONFIG_DIR:-/root/.config/wayvnc}
CONFIG_FILE="$CONFIG_DIR/config"
CREDENTIAL_FILE=${WAYVNC_CREDENTIAL_FILE:-/root/.vnc/wayvnc.credentials}
TLS_DIR=${NOVNC_TLS_DIR:-/root/.config/tigervnc/novnc-tls}
TLS_CERT="$TLS_DIR/novnc-server-fullchain.crt"
TLS_KEY="$TLS_DIR/novnc-server.key"

command -v wayvnc >/dev/null 2>&1 || {
  echo "缺少 wayvnc，请先运行 server_configure.sh" >&2
  exit 1
}
[ -s "$TLS_CERT" ] && [ -s "$TLS_KEY" ] || {
  echo "缺少 noVNC TLS 证书，请先运行 win-git/noVNC.sh" >&2
  exit 1
}

install -d -m 0700 "$CONFIG_DIR" /root/.vnc
if [ ! -s "$CREDENTIAL_FILE" ]; then
  WAYVNC_USER=newhome
  WAYVNC_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
  umask 077
  printf 'username=%s\npassword=%s\n' "$WAYVNC_USER" "$WAYVNC_PASSWORD" \
    >"$CREDENTIAL_FILE"
fi

WAYVNC_USER=$(sed -n 's/^username=//p' "$CREDENTIAL_FILE" | head -1)
WAYVNC_PASSWORD=$(sed -n 's/^password=//p' "$CREDENTIAL_FILE" | head -1)
[ -n "$WAYVNC_USER" ] && [ -n "$WAYVNC_PASSWORD" ] || {
  echo "wayvnc 凭据文件格式错误：$CREDENTIAL_FILE" >&2
  exit 1
}

umask 077
cat >"$CONFIG_FILE" <<EOF
address=127.0.0.1
port=5900
# wayvnc 0.9.1 的认证只向当前 noVNC 公布不兼容的 TLSPlain 子类型 262。
# 它只监听回环地址；用户名密码认证和 TLS 都由外层 websockify 统一提供。
enable_auth=false
EOF
chmod 0600 "$CONFIG_FILE" "$CREDENTIAL_FILE"
echo "wayvnc 配置完成：$CONFIG_FILE"
echo "wayvnc 仅允许本机 noVNC 代理访问；外层连接由 noVNC HTTPS/WSS 加密"
echo "noVNC/websockify 登录凭据保存在：$CREDENTIAL_FILE"
