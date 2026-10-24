#!/bin/bash
. $(dirname "$0")/toolsinit.sh

NAME=noVNC
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

# 默认跟随用户维护的 noVNC fork，其中已直接集成 NewHome/Retina 扩展。
# patch 检测仍保留，供显式指定旧版或官方 NOVNC_GIT_URL 时兼容使用。
NOVNC_GIT_URL=${NOVNC_GIT_URL:-https://github.com/sherylynn/noVNC.git}
NOVNC_BRANCH=${NOVNC_BRANCH:-master}
HIDPI_PATCH=${HIDPI_PATCH:-$HOME/sh/win-git/noVNC_hidpi.patch}
HIDPI_MARKER=NEWHOME_FLAGS_MAGIC
CLIPBOARD_PATCH=${NOVNC_CLIPBOARD_PATCH:-$HOME/sh/win-git/noVNC_firefox_clipboard.patch}
CLIPBOARD_MARKER=NEWHOME_EXPLICIT_PASTE
TLS_HELPER=${NOVNC_TLS_HELPER:-$HOME/sh/win-git/noVNC_tls.sh}
CA_INSTALL_SH=${NOVNC_CA_INSTALL_SH:-$HOME/sh/win-git/install_noVNC_ca.sh}
CA_INSTALL_PS1=${NOVNC_CA_INSTALL_PS1:-$HOME/sh/win-git/install_noVNC_ca.ps1}


FORCE_VNC_PASSWORD_RESET=false
case "${1:-}" in
  --set-password) FORCE_VNC_PASSWORD_RESET=true ;;
  "") ;;
  *) echo "用法: $0 [--set-password]" >&2; exit 2 ;;
esac

configure_native_vnc_password() {
  local credentials=/root/.vnc/vnc.credentials
  local password confirm

  sudo install -d -m 0700 /root/.vnc

  if [ -s /root/.vnc/wayvnc.credentials ]; then
    sudo cp /root/.vnc/wayvnc.credentials "$credentials"
    sudo rm -f /root/.vnc/wayvnc.credentials
  elif [ ! -s "$credentials" ] && [ -s /root/.vnc/novnc.credentials ]; then
    sudo cp /root/.vnc/novnc.credentials "$credentials"
  fi

  if [ -s "$credentials" ] && [ "$FORCE_VNC_PASSWORD_RESET" != true ]; then
    sudo chmod 0600 "$credentials"
    echo "保留现有 NewHome VNC 密码: $credentials"
    echo "如需重新设置：$0 --set-password"
    return 0
  fi

  if [ "$FORCE_VNC_PASSWORD_RESET" = true ]; then
    echo "重新设置 NewHome VNC 密码。"
  fi

  if [ -n "${NEWHOME_VNC_PASSWORD:-}" ]; then
    password=$NEWHOME_VNC_PASSWORD
    password_bytes=$(LC_ALL=C printf '%s' "$password" | wc -c)
    [ "$password_bytes" -le 1024 ] || { echo "NEWHOME_VNC_PASSWORD 超过 1024 UTF-8 bytes" >&2; return 1; }
  elif [ -t 0 ]; then
    echo "请设置 NewHome VNC 密码。支持任意长度 UTF-8 密码，不再受传统 VNC 8 字节限制。"
    while true; do
      printf "VNC 密码: " >&2
      IFS= read -r -s password
      echo >&2
      [ -n "$password" ] || { echo "密码不能为空，请重新输入。"; continue; }
      password_bytes=$(LC_ALL=C printf '%s' "$password" | wc -c)
      [ "$password_bytes" -le 1024 ] || { echo "密码最多 1024 UTF-8 bytes，请重新输入。"; continue; }
      printf "再次输入 VNC 密码: " >&2
      IFS= read -r -s confirm
      echo >&2
      [ "$password" = "$confirm" ] || { echo "两次密码不一致，请重新输入。"; continue; }
      break
    done
  else
    password=$(openssl rand -hex 16)
    echo "非交互安装：已生成随机 NewHome VNC 密码并保存到 $credentials"
  fi

  printf 'password=%s\n' "$password" | sudo tee "$credentials" >/dev/null
  sudo chmod 0600 "$credentials"
}

echo "noVNC upstream: $NOVNC_GIT_URL"
echo "noVNC branch: $NOVNC_BRANCH"
echo "HiDPI patch: $HIDPI_PATCH"
echo "Firefox clipboard patch: $CLIPBOARD_PATCH"
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

apply_clipboard_patch() {
  if grep -q "$CLIPBOARD_MARKER" "${SOFT_HOME}/core/clipboard.js" 2>/dev/null; then
    echo "NewHome Firefox clipboard support already present"
    return 0
  fi
  if [ ! -f "$CLIPBOARD_PATCH" ]; then
    echo "缺少 noVNC Firefox 剪贴板补丁：$CLIPBOARD_PATCH" >&2
    return 1
  fi
  if ! git -C "${SOFT_HOME}" apply --check "$CLIPBOARD_PATCH"; then
    echo "noVNC Firefox 剪贴板补丁无法应用到当前官方版本：$CLIPBOARD_PATCH" >&2
    return 1
  fi
  git -C "${SOFT_HOME}" apply "$CLIPBOARD_PATCH"
  grep -q "$CLIPBOARD_MARKER" "${SOFT_HOME}/core/clipboard.js" || return 1
  echo "applied NewHome Firefox keyboard/right-click clipboard patch"
}

install_https_launcher() {
  local proxy="${SOFT_HOME}/utils/novnc_proxy"

  [ -x "$proxy" ] || {
    echo "找不到 noVNC 启动脚本：$proxy" >&2
    return 1
  }
  [ -f "$TLS_HELPER" ] || {
    echo "找不到 noVNC HTTPS helper：$TLS_HELPER" >&2
    return 1
  }

  grep -q 'NEWHOME_AUTO_TLS' "$proxy" || {
    echo "配置的 noVNC 仓库未集成 NewHome HTTPS 启动逻辑：$proxy" >&2
    return 1
  }
  cp -f "$CA_INSTALL_SH" "${SOFT_HOME}/install-noVNC-ca.sh"
  cp -f "$CA_INSTALL_PS1" "${SOFT_HOME}/install-noVNC-ca.ps1"
  chmod 0755 "${SOFT_HOME}/install-noVNC-ca.sh"
  echo "verified NewHome HTTPS support in maintained noVNC fork"
}

if [[ $(platform) == *linux* ]]; then
  if [ -d "${SOFT_HOME}/.git" ]; then
    echo "refreshing configured noVNC checkout: ${SOFT_HOME}"
    # 清掉上一轮部署产生的工作区 wrapper，再同步配置的仓库分支。
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
  apply_clipboard_patch || exit 1

  sudo apt purge kasmvncserver x11vnc wayvnc tigervnc-standalone-server tigervnc-tools xrdp -y || true
  sudo apt autoremove -y
  # NewHome native compositor owns RFB, clipboard, resize and XWayland.
  # noVNC only needs browser/websocket runtime plus TLS helpers.
  sudo apt install python3-numpy openssl libnss3-tools -y

  # Native RFB owns authentication. Fresh interactive installs ask the user for
  # one full-length password; unattended installs can use NEWHOME_VNC_PASSWORD.
  configure_native_vnc_password || exit 1

  # noVNC's official launcher already supports --cert/--key/--ssl-only. Keep its
  # implementation intact as novnc_proxy.upstream and put our automatic local-CA
  # TLS policy in a wrapper at the original path, which existing startup scripts use.
  install_https_launcher || exit 1

  echo "export PATH=$SOFT_HOME:"'$PATH' >${TOOLSRC}
  echo "noVNC installed from configured repository, NewHome features verified, HTTPS enabled by default"
fi
