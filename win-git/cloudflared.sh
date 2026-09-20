#!/usr/bin/env zsh

# cloudflared.sh —— 安装 cloudflared 官方独立二进制（只从 GitHub release 取）。
#
# 设计目标：macOS 与 Linux 都**只**用官方 GitHub release 的单文件二进制，完全不依赖
# brew / apt。原因：老 macOS（如 12.x）上 brew 只能给到过旧的瓶装版本，而 cloudflared
# 本身是纯 Go 静态二进制（`otool -L` 只链接系统库），直接下官方包即可，与系统版本无关。
#
# 结构对齐 win-git/go.sh：toolsinit.sh + cache_downloader/cache_unpacker + install_path + toolsRC。
#
# 用法：
#   ./cloudflared.sh                    # 安装/更新到最新 release
#   ./cloudflared.sh -v 2026.9.1        # 安装指定版本
#   ./cloudflared.sh -f                 # 强制重装（即使版本已匹配）
#   ./cloudflared.sh -r                 # 安装后卸载 Homebrew 版 cloudflared
#
# 环境变量：
#   CLOUDFLARED_VERSION=2026.9.1        指定版本（留空=最新）
#   CLOUDFLARED_FORCE=1                 强制重装
#   GITHUB_HOST=https://ghproxy.net/https://github.com   下载镜像
#   CLOUDFLARED_SYSTEM_LINK=never|auto|yes  是否额外软链 /usr/local/bin（Linux，永不会弹 sudo 密码）

# 确保 toolsinit.sh 已加载
source "$(dirname "$0")/toolsinit.sh"

# 任一步骤失败时立即停止，避免下载或解压失败后仍然覆盖旧版本并提示成功
set -e

# --- 配置 ---
CLOUDFLARED_VERSION="${CLOUDFLARED_VERSION:-}"
CLOUDFLARED_REPO="${CLOUDFLARED_REPO:-cloudflare/cloudflared}"
# github.com 慢/被墙时可换成镜像前缀，例如 https://ghproxy.net/https://github.com
GITHUB_HOST="${GITHUB_HOST:-https://github.com}"
# Linux 上是否额外软链 /usr/local/bin；默认 never，避免自动化里卡在 sudo 密码提示
CLOUDFLARED_SYSTEM_LINK="${CLOUDFLARED_SYSTEM_LINK:-never}"

FORCE=n
REMOVE_BREW=n
if [[ -n "${CLOUDFLARED_FORCE:-}" ]]; then
  FORCE=y
fi

usage() {
  cat <<'EOF'
用法: cloudflared.sh [选项]

  -v, --version <版本>   安装指定版本（默认取 GitHub 最新 release，如 2026.9.1）
  -f, --force            强制重新下载安装，即使已安装版本已匹配
  -r, --remove-brew      安装成功后卸载 Homebrew 版 cloudflared（macOS，保持只有官方版）
  -h, --help             显示本帮助

环境变量：
  CLOUDFLARED_VERSION        同 -v
  CLOUDFLARED_FORCE=1        同 -f
  GITHUB_HOST                下载镜像前缀，如 https://ghproxy.net/https://github.com
  CLOUDFLARED_SYSTEM_LINK    从未安装 linux 时是否软链 /usr/local/bin：never|auto|yes（默认 never）

安装位置：
  单文件二进制落到 $HOME/tools/bin/cloudflared，并写入 $HOME/tools/rc/cloudflaredrc 把它前置进 PATH。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version)
      if [[ -z "${2:-}" ]]; then
        echo "错误：-v/--version 需要一个版本号，例如 2026.9.1" >&2
        exit 1
      fi
      CLOUDFLARED_VERSION="$2"
      shift 2
      ;;
    -f|--force)
      FORCE=y
      shift
      ;;
    -r|--remove-brew)
      REMOVE_BREW=y
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "错误：未知参数：$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# --- 平台/架构映射（纯函数，可脱离安装流程单独验证）---
# toolsinit 的 platform(): win / wslinux / linux / macos
cf_platform() {
  case "$1" in
    macos)         echo darwin ;;
    linux|wslinux) echo linux ;;
    win)           echo windows ;;
    *)             echo "$1" ;;
  esac
}

# toolsinit 的 arch(): amd64 / aarch64 / armhf / 386
cf_arch() {
  case "$1" in
    amd64)         echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    armhf)         echo armhf ;;
    386)           echo 386 ;;
    *)             echo "$1" ;;
  esac
}

# 官方 release 的资产名；该平台/架构无对应资产时返回非 0
cf_asset() {
  local platform="$1" arch="$2"
  case "$platform" in
    darwin)
      case "$arch" in
        amd64|arm64) echo "cloudflared-darwin-${arch}.tgz" ;;
        *) return 1 ;;
      esac
      ;;
    linux)
      case "$arch" in
        amd64|arm64|armhf|arm|386) echo "cloudflared-linux-${arch}" ;;
        *) return 1 ;;
      esac
      ;;
    windows)
      case "$arch" in
        amd64|386) echo "cloudflared-windows-${arch}.exe" ;;
        *) return 1 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}
# --- 平台/架构映射结束 ---

# --- 脚本主体 ---

echo "准备安装 cloudflared ..."

# 1. 自动检测平台和架构
PLATFORM=$(platform) # win, wslinux, linux, macos
ARCH=$(arch)         # amd64, aarch64, armhf, 386, ...

CF_PLATFORM=$(cf_platform "$PLATFORM")
CF_ARCH=$(cf_arch "$ARCH")

echo "平台: ${CF_PLATFORM}, 架构: ${CF_ARCH}"

# 2. 构造 release 资产名
SOFT_ASSET=$(cf_asset "$CF_PLATFORM" "$CF_ARCH") || {
  echo "错误：cloudflared 官方 release 不提供 ${CF_PLATFORM}/${CF_ARCH} 组合" >&2
  exit 1
}

PACK_EXT=""
case "$SOFT_ASSET" in
  *.tgz) PACK_EXT=".tgz" ;;
  *)     PACK_EXT="" ;;
esac

# 3. 解析版本号：优先命令行/环境变量，其次 GitHub API 查最新
SOFT_VERSION="$CLOUDFLARED_VERSION"
if [[ -z "$SOFT_VERSION" ]]; then
  SOFT_VERSION=$(get_github_release_version "$CLOUDFLARED_REPO" 2>/dev/null | tr -d '[:space:]')
fi

if [[ -n "$SOFT_VERSION" ]]; then
  SOFT_URL_BASE="${GITHUB_HOST}/${CLOUDFLARED_REPO}/releases/download/${SOFT_VERSION}"
  CACHE_BASE="cloudflared-${SOFT_VERSION}-${CF_PLATFORM}-${CF_ARCH}"
  LATEST_FALLBACK=n
else
  # API 不可用（限流/被墙）时仍可用 latest 链接下载，但缓存与解压目录要每次清掉，
  # 否则上一版残留会冒充最新版。
  echo "提示：无法从 GitHub API 获取最新版本号，改用 latest 下载链接。" >&2
  SOFT_URL_BASE="${GITHUB_HOST}/${CLOUDFLARED_REPO}/releases/latest/download"
  CACHE_BASE="cloudflared-latest-${CF_PLATFORM}-${CF_ARCH}"
  LATEST_FALLBACK=y
fi

# 缓存文件名带版本号，避免新旧版本共用同一个缓存文件导致续传/复用错版本
SOFT_FILE_PACK="${CACHE_BASE}${PACK_EXT}"
SOFT_URL="${SOFT_URL_BASE}/${SOFT_ASSET}"

# 4. 安装位置：单文件二进制统一放 ~/tools/bin（与 devspace / server_devspace 的 PATH 约定一致）
CLOUDFLARED_BIN_DIR="$(install_path)/bin"
CLOUDFLARED_BIN="${CLOUDFLARED_BIN_DIR}/cloudflared"

# 5. 已安装同版本则跳过下载
NEED_INSTALL=y
if [[ "$FORCE" != "y" && -n "$SOFT_VERSION" && -x "$CLOUDFLARED_BIN" ]]; then
  CURRENT_VERSION=$("$CLOUDFLARED_BIN" --version 2>/dev/null || true)
  if [[ "$CURRENT_VERSION" == *"$SOFT_VERSION"* ]]; then
    echo "cloudflared ${SOFT_VERSION} 已安装（${CLOUDFLARED_BIN}），跳过下载。"
    echo "如需强制重装：$0 --force"
    NEED_INSTALL=n
  fi
fi

# 6. 下载并安装
if [[ "$NEED_INSTALL" == "y" ]]; then
  if [[ "$LATEST_FALLBACK" == "y" ]]; then
    rm -f "$(cache_folder)/${SOFT_FILE_PACK}"
  fi

  echo "下载: ${SOFT_URL}"
  cache_downloader "$SOFT_FILE_PACK" "$SOFT_URL"

  if [[ "$PACK_EXT" == ".tgz" ]]; then
    SOFT_UNPACK_NAME="$CACHE_BASE"
    if [[ "$LATEST_FALLBACK" == "y" ]]; then
      rm -rf "$(cache_folder)/${SOFT_UNPACK_NAME}"
    fi
    cache_unpacker "$SOFT_FILE_PACK" "$SOFT_UNPACK_NAME"
    SOFT_BIN_SRC="$(cache_folder)/${SOFT_UNPACK_NAME}/cloudflared"
  else
    # 裸二进制：cache_downloader 已经直接下到缓存目录，无需解压
    SOFT_BIN_SRC="$(cache_folder)/${SOFT_FILE_PACK}"
  fi

  # 安装前先验证新二进制可执行，失败则保留现有安装，避免把能用的版本换坏
  if [[ ! -f "$SOFT_BIN_SRC" ]]; then
    echo "错误：下载/解压结果缺少 cloudflared，保留现有安装。" >&2
    exit 1
  fi
  if ! "$SOFT_BIN_SRC" --version >/dev/null 2>&1; then
    echo "错误：新下载的 cloudflared 无法执行，保留现有安装。" >&2
    exit 1
  fi

  mkdir -p "$CLOUDFLARED_BIN_DIR"
  install -m 755 "$SOFT_BIN_SRC" "${CLOUDFLARED_BIN}.new"
  mv -f "${CLOUDFLARED_BIN}.new" "$CLOUDFLARED_BIN"
  echo "已安装：${CLOUDFLARED_BIN}"
else
  mkdir -p "$CLOUDFLARED_BIN_DIR"
fi

# 7. 处理 macOS 隔离属性（走 curl 下载通常没有该属性，这里只是兜底）
if [[ "$CF_PLATFORM" == "darwin" ]]; then
  xattr -d com.apple.quarantine "$CLOUDFLARED_BIN" 2>/dev/null || true
fi

# 8. 配置环境变量 (使用标准 toolsRC 机制)
echo "正在配置环境变量..."
TOOLSRC_FILE=$(toolsRC "cloudflaredrc")
cat >"$TOOLSRC_FILE" <<'EOF'
# cloudflared —— 官方 GitHub release 独立二进制（$HOME/tools/bin），绕过老 macOS 上过旧的 brew 瓶装
# 由 win-git/cloudflared.sh 维护，勿手改
case ":$PATH:" in
  *:"$HOME/tools/bin":*) ;;
  *) export PATH="$HOME/tools/bin:$PATH" ;;
esac
EOF

# 9. Linux 可选软链到 /usr/local/bin（仅在无需 sudo 时执行，绝不触发密码提示）
if [[ "$CLOUDFLARED_SYSTEM_LINK" != "never" && "$CF_PLATFORM" == "linux" ]]; then
  if [[ "$(id -u)" -eq 0 || -w /usr/local/bin ]]; then
    ln -sf "$CLOUDFLARED_BIN" /usr/local/bin/cloudflared
    echo "已软链：/usr/local/bin/cloudflared -> ${CLOUDFLARED_BIN}"
  else
    echo "提示：/usr/local/bin 不可写，跳过软链（PATH 已由 cloudflaredrc 覆盖）。" >&2
  fi
fi

# 10. macOS 上确保只剩官方版：检测并（可选）清理 Homebrew 瓶装版本
BREW_CLOUDFLARED=""
if [[ "$CF_PLATFORM" == "darwin" ]] && command -v brew >/dev/null 2>&1; then
  BREW_PREFIX=$(brew --prefix 2>/dev/null || true)
  if [[ -n "$BREW_PREFIX" && -x "${BREW_PREFIX}/bin/cloudflared" ]]; then
    BREW_CLOUDFLARED="${BREW_PREFIX}/bin/cloudflared"
  fi
fi

if [[ "$REMOVE_BREW" == "y" ]]; then
  if command -v brew >/dev/null 2>&1 && brew list --formula cloudflared >/dev/null 2>&1; then
    echo "正在卸载 Homebrew 版 cloudflared ..."
    brew uninstall cloudflared
    BREW_CLOUDFLARED=""
  else
    echo "Homebrew 未安装 cloudflared，无需清理。"
  fi
fi

# 11. 验证
INSTALLED_VERSION=$("$CLOUDFLARED_BIN" --version 2>/dev/null | head -1 || true)
export PATH="${CLOUDFLARED_BIN_DIR}:$PATH"

echo ""
echo "✅ cloudflared 安装完成！"
echo "   路径: ${CLOUDFLARED_BIN}"
echo "   版本: ${INSTALLED_VERSION:-未知}"
echo "   解析: $(command -v cloudflared 2>/dev/null || echo '需重开终端或 source ~/.zshrc')"
if [[ -n "$BREW_CLOUDFLARED" ]]; then
  echo ""
  echo "⚠️  检测到 Homebrew 版 cloudflared：${BREW_CLOUDFLARED}"
  echo "    PATH 里官方版优先，不影响使用；要彻底清理请执行：$0 --remove-brew"
fi
echo ""
echo "提示：重启服务让新版生效 -> win-git/server_devspace.sh restart"
