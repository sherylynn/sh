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

echo "noVNC upstream: $NOVNC_GIT_URL"
echo "noVNC branch: $NOVNC_BRANCH"
echo "HiDPI patch: $HIDPI_PATCH"

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

if [[ $(platform) == *linux* ]]; then
  if [ -d "${SOFT_HOME}/.git" ]; then
    echo "refreshing official noVNC checkout: ${SOFT_HOME}"
    # 清掉上一轮部署产生的工作区 patch，再同步官方分支，保证每次都从干净 upstream 开始。
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
  sudo apt install python3-numpy x11vnc tigervnc-standalone-server tigervnc-tools -y

  # Browser patch and x11vnc receiver form one protocol pair. Rebuild the receiver
  # here as well as during a fresh desktop installation, so a noVNC-only update
  # cannot leave an older library that silently drops Retina DPI flags.
  sudo apt install gcc binutils libvncserver-dev -y
  bash "$HOME/sh/win-git/build_x11vnc_remote_resize.sh"

  echo "export PATH=$SOFT_HOME:"'$PATH' >${TOOLSRC}
  echo "noVNC installed from official upstream and patched locally"
fi
