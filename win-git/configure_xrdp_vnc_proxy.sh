#!/bin/bash
set -euo pipefail

XRDP_CONFIG=${XRDP_CONFIG:-/etc/xrdp/newhome-x11.ini}
XRDP_CERT_FILE=${XRDP_CERT_FILE:-/etc/xrdp/cert.pem}
XRDP_KEY_FILE=${XRDP_KEY_FILE:-/etc/xrdp/key.pem}
XRDP_DISPLAY_NUMBER=${XRDP_DISPLAY_NUMBER:-1}
XRDP_SESSION_UID=${XRDP_SESSION_UID:-$(id -u)}

case "$XRDP_DISPLAY_NUMBER" in
  ''|*[!0-9]*)
    echo "XRDP_DISPLAY_NUMBER 必须是纯数字，当前值：$XRDP_DISPLAY_NUMBER" >&2
    exit 1
    ;;
esac
case "$XRDP_SESSION_UID" in
  ''|*[!0-9]*)
    echo "XRDP_SESSION_UID 必须是纯数字，当前值：$XRDP_SESSION_UID" >&2
    exit 1
    ;;
esac

mkdir -p "$(dirname "$XRDP_CONFIG")"
cat >"$XRDP_CONFIG" <<EOF
[Globals]
ini_version=1
fork=true
port=3389
tcp_nodelay=true
tcp_keepalive=true
security_layer=negotiate
crypt_level=high
certificate=$XRDP_CERT_FILE
key_file=$XRDP_KEY_FILE
ssl_protocols=TLSv1.2, TLSv1.3
autorun=NewHome-X11
allow_channels=true
allow_multimon=false
bitmap_cache=true
bitmap_compression=true
bulk_compression=true
max_bpp=32
new_cursors=true
use_fastpath=both

[Logging]
LogFile=/root/.vnc/xrdp.log
LogLevel=INFO
EnableSyslog=false

[Channels]
rdpdr=true
rdpsnd=true
drdynvc=true
cliprdr=true
rail=true
xrdpvr=true
tcutils=true

[NewHome-X11]
name=NewHome shared X11 desktop
lib=libvnc.so
ip=127.0.0.1
port=5900
username=ask
password=ask
# 共享已有 VNC/X11 会话时，libvnc 自带的经典 RFB clipboard 只有
# ISO-8859-1。连接到同一 DISPLAY 上手工启动的 xrdp-chansrv 后，
# cliprdr 直接由 chansrv <-> X11 处理，可保留 UTF-8/Unicode。
#
# 不使用 DISPLAY(n) / DISPLAY(n,u) 简写：Debian xrdp 0.10.1 的共享
# VNC 会话无法可靠推导 UID，且 DISPLAY(n,u) 会被该版本判为非法。
# 直接写 chansrv 实际 Unix socket，可同时兼容当前版本并避免回退到
# libvnc 的 ISO-8859-1 clipboard。
chansrvport=/run/xrdp/sockdir/$XRDP_SESSION_UID/xrdp_chansrv_socket_$XRDP_DISPLAY_NUMBER
enable_dynamic_resizing=true
code=0
EOF
chmod 0644 "$XRDP_CONFIG"
echo "XRDP shared-desktop config updated: $XRDP_CONFIG"
