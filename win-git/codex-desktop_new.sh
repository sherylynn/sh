#!/usr/bin/env bash
set -Eeuo pipefail

# One-command installer for the current (official-deb pipeline) codex-desktop-linux.
# 上游 2026-08 完成官方 Linux deb 包迁移：唯一上游来源是 OpenAI 签名的 stable deb
# （amd64/arm64），DMG=/CODEX_DMG_* 输入已移除；resources/app.asar 与官方包逐字节一致。
# 本脚本跟踪上游 main（不固定提交），克隆为 codex-desktop-linux-new，与旧版
# codex-desktop.sh（fork 固定提交 4da3436f 的 DMG 管线）互不干扰，可并存对比。
# The actual build/install logic remains in the upstream repository's Makefile.

readonly REPO_URL="${CODEX_NEW_REPO_URL:-https://github.com/ilysenko/codex-desktop-linux.git}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
readonly TOOLSINIT="${TOOLSINIT:-${SCRIPT_DIR}/toolsinit.sh}"
[[ -r "$TOOLSINIT" ]] || { echo "错误：找不到 toolsinit.sh：$TOOLSINIT" >&2; exit 1; }
PREFIX="${PREFIX:-}"
TMPDIR="${TMPDIR:-}"
. "$TOOLSINIT"
TOOLSRC_NAME=codex-desktop-newrc
TOOLSRC=$(toolsRC "$TOOLSRC_NAME")
TOOLS_HOME=$(install_path)
readonly DEFAULT_DIR="${CODEX_NEW_INSTALL_DIR:-${TOOLS_HOME}/codex-desktop-linux-new}"
readonly CODEX_DATA_DIR="${CODEX_DATA_DIR:-${TOOLS_HOME}/codex-desktop-data}"
readonly DOWNLOAD_DEB_DIR="/sdcard/Download"
export ELECTRON_MIRROR="${ELECTRON_MIRROR:-https://npmmirror.com/mirrors/electron/}"

repo_dir="$DEFAULT_DIR"
deb_path="${CODEX_UPSTREAM_DEB:-}"
setup_features=0
dry_run=0
no_updater=0
update_only=0
uninstall=0
purge_data=0
assume_yes=0
usage() {
  cat <<"EOF"
用法：codex-desktop_new.sh [选项]

基于 codex-desktop-linux 最新 main（官方 OpenAI 签名 deb 路线）的安装器。
源码克隆到 $HOME/tools/codex-desktop-linux-new，与旧版（DMG 管线）目录互不影响。
默认从 OpenAI 签名 stable 索引自动解析 amd64/arm64 官方包；也可用 --deb 指定
本地已下载的官方 chatgpt_<version>_<arch>.deb。

选项：
  --dir DIR          源码目录（默认：$HOME/tools/codex-desktop-linux-new）
  --deb FILE         使用指定官方 deb（默认扫描 /sdcard/Download/chatgpt*.deb，
                     找不到则由官方脚本从签名 stable 索引自动下载）
  --setup            安装前先运行 make setup-native 交互选择可选 Linux 特性
  --no-updater       不构建/安装后台自动更新器
  --update           只更新已有源码，不重新克隆
  --uninstall        卸载 codex-desktop deb 包并删除源码、构建缓存和安装残留
  --purge-data       配合 --uninstall 删除运行配置和登录数据
  --yes              卸载时不询问确认
  --dry-run          只显示将执行的命令，不进行安装
  -h, --help         显示帮助

示例：
  ./codex-desktop_new.sh
  ./codex-desktop_new.sh --deb /sdcard/Download/chatgpt_1.2.3_arm64.deb
  ./codex-desktop_new.sh --setup
  ./codex-desktop_new.sh --uninstall

环境变量：
  CODEX_NEW_REPO_URL / CODEX_NEW_INSTALL_DIR / CODEX_UPSTREAM_DEB
EOF
}

die() { printf '错误：%s\n' "$*" >&2; exit 1; }
info() { printf '\n==> %s\n' "$*"; }
configure_root_runtime() {
  mkdir -p "$CODEX_DATA_DIR"
  local local_launcher="$repo_dir/codex-app/start.sh"
  local installed_launcher="$(command -v codex-desktop 2>/dev/null || true)"
  local config_lines=(
    "export CODEX_DESKTOP_DATA_DIR=$CODEX_DATA_DIR"
    "alias codex-desktop-new-root=\"${installed_launcher:-codex-desktop} --no-sandbox --user-data-dir $CODEX_DATA_DIR\""
    "alias codex-desktop-new-local=\"$local_launcher --no-sandbox --user-data-dir $CODEX_DATA_DIR\""
  )
  for line in "${config_lines[@]}"; do
    grep -Fqx "$line" "$TOOLSRC" 2>/dev/null || printf "%s\n" "$line" >> "$TOOLSRC"
  done
  info "已写入 root 用户配置：$TOOLSRC"
}
ensure_managed_rust() {
  local rust_rc="$TOOLS_HOME/rc/rustrc"
  local cargo_env="$TOOLS_HOME/cargo/env"
  local cargo_version
  if [[ -r "$rust_rc" ]]; then
    source "$rust_rc"
  elif [[ -r "$cargo_env" ]]; then
    export RUSTUP_HOME="$TOOLS_HOME/rustup"
    export CARGO_HOME="$TOOLS_HOME/cargo"
    source "$cargo_env"
  fi
  if command -v cargo >/dev/null 2>&1 && cargo_version=$(cargo --version 2>/dev/null); then
    info "使用已有 Rust 工具链：$cargo_version"
    return
  fi

  info "使用 win-git/rustup.sh 安装和管理 Rust stable"
  "$SCRIPT_DIR/rustup.sh"
  [[ -r "$rust_rc" ]] || die "Rust 安装完成，但找不到环境配置：$rust_rc"
  source "$rust_rc"
  cargo --version >/dev/null 2>&1 || die "Rust 安装后 cargo 仍不可用"
}

remove_codex_config_lines() {
  [[ -f "$TOOLSRC" ]] || return 0
  sed -i \
    -e '/^export CODEX_DESKTOP_DATA_DIR=/d' \
    -e '/^alias codex-desktop-new-root=/d' \
    -e '/^alias codex-desktop-new-local=/d' \
    "$TOOLSRC"
}

stop_codex_processes() {
  local pid
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    kill "$pid" 2>/dev/null || true
  done < <(pgrep -f '/opt/codex-desktop|codex-desktop-linux-new/codex-app' 2>/dev/null || true)
}

uninstall_codex_desktop() {
  local -a targets=(
    "$repo_dir"
    "${XDG_CACHE_HOME:-$HOME/.cache}/codex-desktop"
    "$CODEX_DATA_DIR"
    "${XDG_CONFIG_HOME:-$HOME/.config}/codex-desktop"
  )
  local target answer

  if ((assume_yes == 0)); then
    printf '将卸载 codex-desktop deb 包，并删除以下源码/构建目录：\n'
    printf '  - %s\n' "${targets[0]}" "${targets[1]}"
    if ((purge_data == 1)); then
      printf '同时删除以下运行配置和登录数据：\n'
      printf '  - %s\n' "${targets[2]}" "${targets[3]}"
    else
      printf '运行配置和登录数据将保留；如需删除请加 --purge-data。\n'
    fi
    read -r -p '确认继续卸载？[y/N] ' answer
    [[ "$answer" =~ ^[Yy]$ ]] || { info '已取消卸载'; return 0; }
  fi

  info '停止 Codex Desktop 相关进程'
  stop_codex_processes

  if dpkg-query -W -f='${Status}' codex-desktop 2>/dev/null | grep -Fq 'install ok installed'; then
    info '卸载 codex-desktop deb 包'
    if command -v apt-get >/dev/null 2>&1; then
      apt-get purge -y codex-desktop
    else
      dpkg --purge codex-desktop
    fi
  else
    info '未检测到已安装的 codex-desktop deb 包'
  fi

  for target in "${targets[@]:0:2}"; do
    if [[ -n "$target" && "$target" != "/" && -e "$target" ]]; then
      info "删除：$target"
      rm -rf -- "$target"
    fi
  done

  if ((purge_data == 1)); then
    for target in "${targets[@]:2:2}"; do
      if [[ -n "$target" && "$target" != "/" && -e "$target" ]]; then
        info "删除运行数据：$target"
        rm -rf -- "$target"
      fi
    done
  fi
  remove_codex_config_lines
  info '卸载完成；共享 Rust、Node、系统依赖和 /sdcard/Download 文件均已保留'
}
find_downloaded_deb() (
  local candidate newest=""
  local -a candidates
  shopt -s nullglob nocaseglob
  candidates=("$DOWNLOAD_DEB_DIR"/chatgpt*.deb "$DOWNLOAD_DEB_DIR"/*chatgpt*.deb)
  for candidate in "${candidates[@]}"; do
    if [[ -z "$newest" || "$candidate" -nt "$newest" ]]; then
      newest="$candidate"
    fi
  done
  printf "%s" "$newest"
)

while (($#)); do
  case "$1" in
    --dir)
      (($# >= 2)) || die "--dir 需要一个目录"
      repo_dir=$2
      shift 2
      ;;
    --deb)
      (($# >= 2)) || die "--deb 需要一个文件路径"
      deb_path=$2
      shift 2
      ;;
    --setup) setup_features=1; shift ;;
    --no-updater) no_updater=1; shift ;;
    --update) update_only=1; shift ;;
    --uninstall) uninstall=1; shift ;;
    --purge-data) purge_data=1; shift ;;
    --yes) assume_yes=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知选项：$1（使用 --help 查看帮助）" ;;
  esac
done

if ((uninstall == 1)); then
  ((dry_run == 0)) || { printf '预览：卸载 codex-desktop deb 包、源码目录和构建缓存'; ((purge_data == 1)) && printf '，并删除运行数据'; printf '\n'; exit 0; }
  uninstall_codex_desktop
  exit 0
fi

((purge_data == 0)) || die '--purge-data 只能与 --uninstall 一起使用'
((assume_yes == 0)) || die '--yes 只能与 --uninstall 一起使用'

command -v git >/dev/null || die "缺少 git，请先安装 git。"
if [[ -z "$deb_path" ]]; then
  deb_path=$(find_downloaded_deb)
fi
if [[ -n "$deb_path" ]]; then
  [[ -f "$deb_path" ]] || die "找不到官方 deb：$deb_path"
  deb_path=$(realpath "$deb_path")
  info "使用本地官方 deb：$deb_path"
else
  info "下载目录未发现官方 deb，将由官方脚本从签名 stable 索引自动解析下载"
fi

command -v make >/dev/null || die "缺少 make，请先安装 make。"

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  info "检测到 ${PRETTY_NAME:-Linux}（$(uname -m)）"
else
  info "检测到 Linux（$(uname -m)）"
fi

if [[ -e "$repo_dir/.git" ]]; then
  info "复用源码目录：$repo_dir"
  if ((dry_run == 0)); then
    git -C "$repo_dir" fetch --depth=1 origin main
    git -C "$repo_dir" reset --hard origin/main
  fi
else
  ((update_only == 0)) || die "找不到源码目录：$repo_dir；首次运行请去掉 --update。"
  info "浅克隆最新源码到：$repo_dir"
  if ((dry_run == 0)); then
    mkdir -p "$(dirname "$repo_dir")"
    git clone --depth=1 "$REPO_URL" "$repo_dir"
  fi
fi

if [[ -n "$deb_path" ]]; then
  # 本地官方包：跳过签名索引发现，仍校验包名/架构/control/载荷完整性
  make_target="install-native"
  make_vars=("UPSTREAM_DEB=$deb_path")
else
  make_target="bootstrap-native"
  make_vars=()
fi
if ((no_updater == 1)); then
  export PACKAGE_WITH_UPDATER=0
  info "已关闭后台自动更新器"
fi

if ((dry_run == 1)); then
  printf '预览：克隆/更新 %q 后：cd %q && make' "$REPO_URL" "$repo_dir"
  ((setup_features == 1)) && printf ' setup-native &&'
  printf ' %q' "$make_target"
  ((${#make_vars[@]})) && printf ' %q' "${make_vars[@]}"
  printf '\n'
  exit 0
fi

ensure_managed_rust
info "开始构建并安装（官方流程可能会请求 sudo）"
cd "$repo_dir"
if ((setup_features == 1)); then
  make setup-native
fi
make "$make_target" "${make_vars[@]}"

configure_root_runtime
info "安装完成。可从应用菜单启动 ChatGPT Community，或运行："
printf '  %q/codex-app/start.sh\n' "$repo_dir"
