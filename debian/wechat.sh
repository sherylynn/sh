#!/bin/bash
# Native Linux WeChat; server_configure.sh invokes this script with zsh.
set -eu
if [ "$(uname -s)" != Linux ] || ! command -v dpkg >/dev/null 2>&1; then
  echo '需要 Debian/Ubuntu Linux 环境。' >&2
  exit 1
fi
case "$(dpkg --print-architecture)" in
  arm64) wechat_arch=arm64 ;;
  amd64) wechat_arch=x86_64 ;;
  *) echo '官方安装脚本目前只支持 arm64 和 amd64。' >&2; exit 1 ;;
esac
# 官方 URL 会更新；每次重新下载，避免把缓存中的旧版本当作最新版。
wechat_url="https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_${wechat_arch}.deb"
wechat_tmp=$(mktemp -d)
trap 'rm -f "$wechat_tmp/wechat.deb"; rmdir "$wechat_tmp"' EXIT
if [ "$(id -u)" = 0 ]; then
  wechat_sudo=''
else
  wechat_sudo=sudo
fi
command -v curl >/dev/null 2>&1 || $wechat_sudo apt-get install -y curl ca-certificates
curl --fail --location --retry 3 --connect-timeout 20 --max-time 600 \
  --output "$wechat_tmp/wechat.deb" "$wechat_url"
[ "$(dpkg-deb -f "$wechat_tmp/wechat.deb" Package)" = wechat ]
[ "$(dpkg-deb -f "$wechat_tmp/wechat.deb" Architecture)" = "$(dpkg --print-architecture)" ]
echo "安装官方微信 $(dpkg-deb -f "$wechat_tmp/wechat.deb" Version)"
# apt 自动处理依赖；不要将 libtiff.so.6 冒充 libtiff.so.5。
chmod 755 "$wechat_tmp"
chmod 644 "$wechat_tmp/wechat.deb"
$wechat_sudo apt-get install -y "$wechat_tmp/wechat.deb"

# 小程序使用独立运行时，必须另外检查它的依赖。
wechat_runtime=/opt/wechat/RadiumWMPF/runtime/WeChatAppEx
if [ -x "$wechat_runtime" ]; then
  wechat_missing=$(ldd "$wechat_runtime" | awk '/not found/ {print $1}')
  if [ -n "$wechat_missing" ]; then
    printf '小程序运行时缺少动态库：\n%s\n' "$wechat_missing" >&2
    exit 1
  fi
else
  echo '安装包中未找到小程序运行时 WeChatAppEx。' >&2
  exit 1
fi
if [ ! -d /dev/shm ] || [ ! -w /dev/shm ]; then
  echo 'chroot 必须提供可写的 /dev/shm；请在宿主挂载 tmpfs 后再启动微信。' >&2
fi
# chroot 中通常没有 pam_systemd 为桌面进程设置运行时目录。
$wechat_sudo install -d /usr/local/bin
$wechat_sudo tee /usr/local/bin/wechat-chroot >/dev/null <<'EOF'
#!/bin/sh
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
  wechat_uid=$(id -u)
  wechat_runtime="/run/user/$wechat_uid"
  if [ ! -d "$wechat_runtime" ] && [ "$wechat_uid" = 0 ]; then
    mkdir -p "$wechat_runtime"
    chmod 700 "$wechat_runtime"
  fi
  if [ -d "$wechat_runtime" ] && [ "$(stat -c %u "$wechat_runtime")" = "$wechat_uid" ] && [ "$(stat -c %a "$wechat_runtime")" = 700 ]; then
    export XDG_RUNTIME_DIR="$wechat_runtime"
  else
    echo '未找到安全的 XDG_RUNTIME_DIR，请在桌面会话中设置。' >&2
  fi
fi
exec /usr/bin/wechat "$@"
EOF
$wechat_sudo chmod 755 /usr/local/bin/wechat-chroot
# 保留系统启动项的缩放参数，通过用户启动项修复 chroot 环境。
wechat_app_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$wechat_app_dir"
sed 's|/usr/bin/wechat|/usr/local/bin/wechat-chroot|g' \
  /usr/share/applications/wechat.desktop > "$wechat_app_dir/wechat.desktop"
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$wechat_app_dir"
fi
echo '安装完成；请退出原有微信进程后重新启动，再测试小程序。'
