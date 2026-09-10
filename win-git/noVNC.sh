#!/bin/bash
. $(dirname "$0")/toolsinit.sh

NAME=noVNC
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}

# 默认使用自己的 noVNC fork。需要临时切回其他仓库时可覆盖 NOVNC_GIT_URL。
NOVNC_GIT_URL=${NOVNC_GIT_URL:-https://github.com/sherylynn/noVNC.git}
NOVNC_BRANCH=${NOVNC_BRANCH:-master}
HIDPI_PATCH=${HIDPI_PATCH:-$HOME/sh/win-git/noVNC_hidpi.patch}

echo "noVNC repository: $NOVNC_GIT_URL"
echo "noVNC branch: $NOVNC_BRANCH"

case $(arch) in
  amd64) SOFT_ARCH=x86_64 ;;
  386) SOFT_ARCH=386 ;;
  armhf) SOFT_ARCH=armhf ;;
  aarch64) SOFT_ARCH=aarch64 ;;
esac

PLATFORM=$(platform)

if [[ $(platform) == *linux* ]]; then
  if [ -d "${SOFT_HOME}/.git" ]; then
    echo "updating existing noVNC checkout: ${SOFT_HOME}"
    # 本地 checkout 可能带有上一轮安装时应用的 HiDPI patch，先恢复到仓库状态。
    git -C "${SOFT_HOME}" reset --hard
    git -C "${SOFT_HOME}" remote set-url origin "${NOVNC_GIT_URL}"
    git -C "${SOFT_HOME}" fetch --depth 1 origin "${NOVNC_BRANCH}"
    git -C "${SOFT_HOME}" checkout -B "${NOVNC_BRANCH}" "origin/${NOVNC_BRANCH}"
  else
    rm -rf "${SOFT_HOME}"
    git clone --depth 1 --branch "${NOVNC_BRANCH}" "${NOVNC_GIT_URL}" "${SOFT_HOME}"
  fi

  # 当前 GitHub connector 对 sherylynn/noVNC 写入返回 403，因此把同一补丁保存在 sh
  # 仓库中并在安装时自动应用。等 fork 自身合入后，marker 检测会自动跳过本步骤。
  if ! grep -q 'NEWHOME_FLAGS_MAGIC' "${SOFT_HOME}/core/rfb.js"; then
    if [ ! -f "$HIDPI_PATCH" ]; then
      echo "缺少 noVNC HiDPI 补丁：$HIDPI_PATCH" >&2
      exit 1
    fi
    if git -C "${SOFT_HOME}" apply --check "$HIDPI_PATCH"; then
      git -C "${SOFT_HOME}" apply "$HIDPI_PATCH"
      echo "applied NewHome HiDPI remote-resize patch"
    else
      echo "noVNC HiDPI 补丁无法应用；fork 版本可能已变化，请更新补丁。" >&2
      exit 1
    fi
  else
    echo "NewHome HiDPI support already present in noVNC fork"
  fi

  sudo apt purge kasmvncserver -y
  sudo apt autoremove -y
  sudo apt install python3-numpy x11vnc tigervnc-standalone-server tigervnc-tools -y

  echo "export PATH=$SOFT_HOME:"'$PATH' >${TOOLSRC}
  echo "noVNC installed from ${NOVNC_GIT_URL} (${NOVNC_BRANCH})"
fi
