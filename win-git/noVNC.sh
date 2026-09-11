#!/bin/bash
. $(dirname "$0")/toolsinit.sh

NAME=noVNC
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

# 始终跟随官方 noVNC；NewHome/Retina 扩展由 sh 仓库中的 patch 在部署时叠加。
NOVNC_GIT_URL=${NOVNC_GIT_URL:-https://github.com/novnc/noVNC.git}
NOVNC_BRANCH=${NOVNC_BRANCH:-master}
HIDPI_PATCH=${HIDPI_PATCH:-$HOME/sh/win-git/noVNC_hidpi.patch}
HIDPI_MARKER=NEWHOME_FLAGS_MAGIC
TLS_HELPER=${NOVNC_TLS_HELPER:-$HOME/sh/win-git/noVNC_tls.sh}

echo "noVNC upstream: $NOVNC_GIT_URL"
echo "noVNC branch: $NOVNC_BRANCH"
echo "HiDPI patch: $HIDPI_PATCH"
echo "HTTPS helper: $TLS_HELPER"

case $(arch) in
  amd64) SOFT_ARCH=x86_64 ;;
  386) SOFT_ARCH=386 ;;
  armhf) SOFT_ARCH=armhf ;;
  aarch64) SOFT_ARCH=aarch64 ;;
esac

PLATFORM=$(platform)

apply_hidpi_patch() {
  if grep -q "$HIDPI_MARKER" "${SOFT_HOME}/core/rfb.js" 2>/dev/null; then
    echo "NewHome HiDPI support already present"
    return 0
  fi

  if [ ! -f "$HIDPI_PATCH" ]; then
    echo "缺少 noVNC HiDPI 补丁：$HIDPI_PATCH" >&2
    return 1
  fi

  patch_check_output=$(git -C "${SOFT_HOME}" apply --check --verbose "$HIDPI_PATCH" 2>&1) || {
    echo "noVNC HiDPI 补丁无法应用到当前官方版本。" >&2
    echo "$patch_check_output" >&2
    echo "官方 noVNC 可能已经修改了 core/rfb.js；请更新 $HIDPI_PATCH。" >&2
    return 1
  }

  git -C "${SOFT_HOME}" apply "$HIDPI_PATCH"
  grep -q "$HIDPI_MARKER" "${SOFT_HOME}/core/rfb.js" || {
    echo "HiDPI 补丁执行后未找到 marker，拒绝继续。" >&2
    return 1
  }
  echo "applied NewHome HiDPI/Retina patch to official noVNC"
}

install_https_launcher() {
  local proxy="${SOFT_HOME}/utils/novnc_proxy"
  local upstream="${SOFT_HOME}/utils/novnc_proxy.upstream"

  [ -x "$proxy" ] || {
    echo "找不到官方 noVNC 启动脚本：$proxy" >&2
    return 1
  }
  [ -f "$TLS_HELPER" ] || {
    echo "找不到 noVNC HTTPS helper：$TLS_HELPER" >&2
    return 1
  }

  # 每次部署都从刚同步的官方启动器复制一份，再把公开入口换成很薄的
  # NewHome wrapper。server_noVNC.sh 无需关心 TLS 参数，仍调用 novnc_proxy。
  cp -f "$proxy" "$upstream"
  chmod 0755 "$upstream"

  cat > "$proxy" <<'EOF'
#!/usr/bin/env bash
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM="$HERE/novnc_proxy.upstream"
TLS_HELPER=${NOVNC_TLS_HELPER:-$HOME/sh/win-git/noVNC_tls.sh}

[ -x "$UPSTREAM" ] || {
  echo "noVNC upstream launcher missing: $UPSTREAM" >&2
  exit 1
}

# Explicit upstream TLS flags always win. This keeps the wrapper compatible
# with callers that already manage their own certificates.
explicit_tls=0
for arg in "$@"; do
  case "$arg" in
    --cert|--key|--ssl-only) explicit_tls=1 ;;
  esac
done

case "${NOVNC_HTTPS:-1}" in
  0|off|false|no)
    exec "$UPSTREAM" "$@"
    ;;
  *)
    if [ "$explicit_tls" -eq 1 ]; then
      exec "$UPSTREAM" "$@"
    fi
    [ -f "$TLS_HELPER" ] || {
      echo "noVNC HTTPS helper missing: $TLS_HELPER" >&2
      exit 1
    }
    # shellcheck source=/dev/null
    . "$TLS_HELPER"
    novnc_tls_prepare || exit 1
    echo "[noVNC TLS] HTTPS/WSS enabled (set NOVNC_HTTPS=0 to use plain HTTP)"
    exec "$UPSTREAM" \
      --cert "$NOVNC_TLS_CERT" \
      --key "$NOVNC_TLS_KEY" \
      --ssl-only \
      "$@"
    ;;
esac
EOF
  chmod 0755 "$proxy"
  echo "installed NewHome HTTPS wrapper over official novnc_proxy"
}

if [[ $(platform) == *linux* ]]; then
  if [ -d "${SOFT_HOME}/.git" ]; then
    echo "refreshing official noVNC checkout: ${SOFT_HOME}"
    # 清掉上一轮部署产生的工作区 patch/wrapper，再同步官方分支，保证每次都从干净 upstream 开始。
    git -C "${SOFT_HOME}" reset --hard
    git -C "${SOFT_HOME}" clean -fd
    git -C "${SOFT_HOME}" remote set-url origin "${NOVNC_GIT_URL}"
    git -C "${SOFT_HOME}" fetch --depth 1 origin "${NOVNC_BRANCH}"
    git -C "${SOFT_HOME}" checkout -B "${NOVNC_BRANCH}" "origin/${NOVNC_BRANCH}"
  else
    rm -rf "${SOFT_HOME}"
    git clone --depth 1 --branch "${NOVNC_BRANCH}" "${NOVNC_GIT_URL}" "${SOFT_HOME}"
  fi

  apply_hidpi_patch || exit 1

  sudo apt purge kasmvncserver -y
  sudo apt autoremove -y
  sudo apt install python3-numpy x11vnc tigervnc-standalone-server tigervnc-tools openssl -y

  # Browser patch and x11vnc receiver form one protocol pair. Rebuild the receiver
  # here as well as during a fresh desktop installation, so a noVNC-only update
  # cannot leave an older library that silently drops Retina DPI flags.
  sudo apt install gcc binutils libvncserver-dev -y
  bash "$HOME/sh/win-git/build_x11vnc_remote_resize.sh"

  # noVNC's official launcher already supports --cert/--key/--ssl-only. Keep its
  # implementation intact as novnc_proxy.upstream and put our automatic local-CA
  # TLS policy in a wrapper at the original path, which existing startup scripts use.
  install_https_launcher || exit 1

  echo "export PATH=$SOFT_HOME:"'$PATH' >${TOOLSRC}
  echo "noVNC installed from official upstream, patched locally, HTTPS enabled by default"
fi
