#!/bin/bash
. $(dirname "$0")/toolsinit.sh
NAME=mesa
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})

REPO_OWNER=lfdevs
REPO_NAME=mesa-for-android-container
SOFT_HOME=$(install_path)/${REPO_NAME}
# releases/latest 可能指向 turnip-*（未打 xMeM 原始补丁的覆盖包），
# Adreno 7xx/8xx 按上游建议应优先使用标准 mesa-* release。
github_api_get() {
  local url="$1"
  local body

  if body="$(curl --retry 3 --retry-delay 1 --retry-all-errors -fsSL "$url")"; then
    printf '%s' "$body"
    return 0
  fi

  echo "GitHub API 经当前代理访问失败，尝试直连：$url" >&2
  env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
    curl --retry 3 --retry-delay 1 --retry-all-errors -fsSL "$url"
}

get_latest_standard_mesa_tag() {
  github_api_get "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases?per_page=30" |
    grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"mesa-[^"]+"' |
    head -n 1 |
    sed -E 's/.*"(mesa-[^"]+)"/\1/'
}

get_release_asset_sha256() {
  local tag="$1"
  local asset="$2"
  github_api_get "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/tags/$tag" |
    python3 -c '
import json, sys
asset_name = sys.argv[1]
for item in json.load(sys.stdin).get("assets", []):
    if item.get("name") == asset_name:
        digest = item.get("digest") or ""
        if digest.startswith("sha256:"):
            print(digest.split(":", 1)[1])
        break
' "$asset"
}

SOFT_VERSION=$(get_latest_standard_mesa_tag)
if [ -z "$SOFT_VERSION" ]; then
  echo "无法从 GitHub 获取最新标准 Mesa release。" >&2
  exit 1
fi
echo "latest standard Mesa release is $SOFT_VERSION"

mkdir -p "$SOFT_HOME"

case $(arch) in
  amd64) SOFT_ARCH=x64 ;;
  386) SOFT_ARCH=x86 ;;
  armhf) SOFT_ARCH=armv7l ;;
  aarch64)
    #检测是否强制使用虚拟显卡
    if [ -f "/sdcard/Download/使用虚拟显卡.txt" ]; then
      echo "检测到强制使用虚拟显卡文件，跳过Oryon驱动安装"
      exit 0
    elif lscpu | grep -q "Oryon"; then
      echo "检测到 Oryon / Adreno 8xx，安装标准 Mesa + patched Turnip/Freedreno..."

      VERSION_PART="${SOFT_VERSION#mesa-}"
      MESA_TAG="$SOFT_VERSION"

      # 当前 Oryon 设备运行 Debian 13 (trixie)。上游明确要求发行版后缀匹配。
      if [ -r /etc/os-release ]; then
        . /etc/os-release
      fi
      if [ "${ID:-}" != "debian" ] || [ "${VERSION_CODENAME:-}" != "trixie" ]; then
        echo "错误：Oryon 自动安装目前只验收 Debian 13 (trixie)，当前为 ${PRETTY_NAME:-unknown}。" >&2
        exit 1
      fi

      MESA_NAME="mesa-for-android-container_${VERSION_PART}_debian_trixie_arm64.tar.gz"
      MESA_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${MESA_TAG}/${MESA_NAME}"
      EXPECTED_SHA256="$(get_release_asset_sha256 "$MESA_TAG" "$MESA_NAME")"

      if [ -z "$EXPECTED_SHA256" ]; then
        echo "错误：无法从 GitHub release metadata 获取 $MESA_NAME 的 SHA-256。" >&2
        exit 1
      fi

      cache_downloader "$MESA_NAME" "$MESA_URL"
      MESA_ARCHIVE="$(cache_folder)/$MESA_NAME"
      ACTUAL_SHA256="$(sha256sum "$MESA_ARCHIVE" | awk '{print $1}')"
      if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "错误：Mesa 安装包 SHA-256 校验失败。" >&2
        echo "期望：$EXPECTED_SHA256" >&2
        echo "实际：$ACTUAL_SHA256" >&2
        exit 1
      fi

      echo "SHA-256 校验通过：$ACTUAL_SHA256"
      echo "Installing $MESA_NAME..."

      # 上游已确认 Adreno 7xx/8xx 通常不再需要 turnip-* 未打补丁覆盖包。
      # 标准包同时包含 patched Turnip 和 Freedreno/KGSL，直接覆盖安装即可。
      sudo tar -xzf "$MESA_ARCHIVE" -C /
      sudo ldconfig

      cat >"$TOOLSRC" <<'EOF'
# Mesa for Android Container - Adreno 7xx/8xx
# 标准 release 已包含 patched Turnip/Freedreno；OpenGL 直接使用 KGSL，不再默认走 Zink。
export MESA_LOADER_DRIVER_OVERRIDE=kgsl
export XDG_RUNTIME_DIR=/tmp
EOF
      export MESA_LOADER_DRIVER_OVERRIDE=kgsl
      export XDG_RUNTIME_DIR=/tmp

      echo "Oryon / Adreno 8xx 标准驱动安装完成：$MESA_TAG"
      echo "未安装 turnip-* 未打补丁覆盖包。"
      exit 0 # Exit successfully after handling the special case
    elif lscpu | grep -q "骁龙865可以用"; then
      # Default aarch64 behavior (non-Oryon)
      echo 'export MESA_LOADER_DRIVER_OVERRIDE=zink' >${TOOLSRC}
      #echo 'export GALLIUM_DRIVER=zink'>>${TOOLSRC}
      echo 'export TU_DEBUG=noconform' >>${TOOLSRC}
      echo 'export XDG_RUNTIME_DIR=/tmp' >>${TOOLSRC}
      mesa_url="https://raw.githubusercontent.com/sherylynn/fonts/main/mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb"
      mesa_name="mesa-vulkan-kgsl_24.1.0-devel-20240120_arm64.deb"
      $(cache_downloader $mesa_name $mesa_url)
      sudo dpkg -i $(cache_folder)/$mesa_name
      sudo apt install -f -y
    fi
    ;;
esac
#需要安装mesa后，调用termux下的命令就可以启动了
#termux 下 运行mesa.sh 再切换su 运行 mesa.sh
#并把/data/data/com.termux/files/usr/tmp/ 挂载 /tmp/

#echo 'export GALLIUM_DRIVER=virpipe' >${TOOLSRC}
#echo 'export MESA_GL_VERSION_OVERRIDE=4.0'>> ${TOOLSRC}
#echo 'export XDG_RUNTIME_DIR=/tmp'>>${TOOLSRC}
