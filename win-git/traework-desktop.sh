#!/usr/bin/env bash
set -Eeuo pipefail

# TraeWork CN（TRAE SOLO CN）macOS DMG → Linux arm64 移植脚本（草案，P0/P1 阶段迭代用）
#
# 仿照本目录 codex-desktop.sh 的交互风格（中文提示、die/info、/sdcard/Download 扫描、
# toolsinit 集成），移植管线自包含实现，不依赖上游 Makefile —— 参照物为
# codex-desktop-linux 迁移前基线（提交 4da3436f）的 scripts/lib/dmg.sh 与
# scripts/lib/native-modules.sh，完整论证见 ~/traework-port-report/traework-port-report.html。
#
# 供体实测结论（2026-08-18，Trae_CN-linux-arm64.deb 2.3.62837，data.tar 全量复核）：
#   Trae CN 与 TraeWork 同一 monorepo（同 VSCode 1.107.1、同 @aha-kit/electron 39.2.7、
#   内嵌 package.json 依赖逐字一致：ipc@1.0.7 / net@0.4.0-dev.25113f69 / trae-network-client@0.5.0-dev.1351818）。
#   deb 内：闭源模块为纯 JS loader（无 .node）；@aha-kit/net 的 -linux-arm64-gnu 变体包官方就不带
#   （TTNet 适配层由调用方 try/catch 兜底），真正的网络栈由定制 Electron 二进制直接链接根目录
#   libaha_net.so → libsscronet.so（trae-cn 内嵌字符串已证）；logifier/simplelog 同理挂根目录。
#   modules/ 四件：ai-agent、ckg、sandbox、browser-bridge 均为 linux-arm64 ELF（machine=0xB7），
#   main.js 按 platform 三元选文件名（libckg.so / libai_agent.so），无需补丁。
#   预编译 .node 仅 4 件：sqlite3 / spdlog / node-pty / @parcel/watcher；
#   native-watchdog / native-keymap / native-is-elevated 官方 Linux 就不带（keymap 为动态
#   import 可降级，is-elevated 非 Windows 走 process.getuid()===0，watchdog 仅存于 package.json）。
#   @byted-fe/ripgrep-linux-arm64、fd-linux-arm64 为现成 ELF；trae-macos-native 非 darwin
#   导出官方空实现（createNullWindowCapture）。
#   → 有 deb 供体时整条"重编 + stub"路线可整体跳过。
#
# 管线：解包 DMG → 探测 Electron 版本 → 准备 Linux 运行时（deb 供体整包 / stock zip）
#       → 拼装 resources/app → 平台补丁 → 供体覆盖层（或重编+stub 回退）
#       → [可选 --nsbox] 替换 trae-sandbox → start.sh 启动器
#
# 用法示例：
#   ./traework-desktop.sh                                            # 扫描 /sdcard/Download 自动发现 DMG
#   ./traework-desktop.sh --dmg /sdcard/Download/TraeWork_CN-darwin-arm64.dmg
#   ./traework-desktop.sh --donor /sdcard/Download/Trae_CN-linux-arm64.deb    # 供体模式（推荐）
#   ./traework-desktop.sh --no-native                                # 跳过原生模块（仅验证主进程）
#   ./traework-desktop.sh --dry-run
#   ./traework-desktop.sh --uninstall [--purge-data --yes]

readonly SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
readonly TOOLSINIT="${TOOLSINIT:-${SCRIPT_DIR}/toolsinit.sh}"
[[ -r "$TOOLSINIT" ]] || { echo "错误：找不到 toolsinit.sh：$TOOLSINIT" >&2; exit 1; }
PREFIX="${PREFIX:-}"
TMPDIR="${TMPDIR:-}"
. "$TOOLSINIT"
TOOLSRC_NAME=traeworkrc
TOOLSRC=$(toolsRC "$TOOLSRC_NAME")
TOOLS_HOME=$(install_path)

readonly APP_ID="trae-solo-cn"
readonly APP_DISPLAY_NAME="TRAE SOLO CN"
install_dir="${TRAEWORK_INSTALL_DIR:-${TOOLS_HOME}/traework-desktop}"
DATA_DIR="${TRAEWORK_DATA_DIR:-${TOOLS_HOME}/traework-desktop-data}"
readonly DOWNLOAD_DIR="/sdcard/Download"
readonly ELECTRON_MIRROR="${ELECTRON_MIRROR:-https://npmmirror.com/mirrors/electron/}"
readonly ELECTRON_HEADERS_URL="${ELECTRON_HEADERS_URL:-https://artifacts.electronjs.org/headers/dist}"
readonly ELECTRON_REBUILD_PACKAGE="@electron/rebuild@4.0.4"

# 开源可重编（npm 公共源有源码；kerberos 可选，默认不装）——仅无供体回退路线使用
readonly REBUILD_MODULES=("@vscode/sqlite3" "@vscode/spdlog" "node-pty" "native-watchdog" "native-keymap" "native-is-elevated")
# npm prebuild 直取（主包 JS loader + linux-arm64 变体包）
readonly PREBUILD_MODULES=("@parcel/watcher")
# deb 供体内实际预编译的 .node（实测仅此 4 件；watchdog/keymap/is-elevated 官方 Linux 不带）
readonly DONOR_PREBUILD_PACKAGES=("@vscode/sqlite3" "@vscode/spdlog" "node-pty" "@parcel/watcher")
# 官方 Linux 即缺失、可安全不带的模块（keymap 动态 import 降级 / is-elevated 走 getuid / watchdog 未被引用）
readonly DONOR_ABSENT_MODULES=("native-watchdog" "native-keymap" "native-is-elevated")
# 闭源私有包：deb 供体内为纯 JS loader（无原生二进制），整树覆盖即可
readonly DONOR_JS_PACKAGES=("@aha-kit/ipc" "@aha-kit/net" "@aha-kit/perf-sdk" "@aha-kit/rpc" "@byted-icube/trae-network-client" "@byted-icube/trae-macos-native")
# 供体内现成的 linux-arm64 ELF 工具包
readonly DONOR_TOOL_PACKAGES=("@byted-fe/ripgrep-linux-arm64" "@byted-fe/fd-linux-arm64")
# 供体应用根目录的原生 .so（含网络栈），需放到移植目录根部
readonly DONOR_ROOT_LIBS=("libaha_net.so" "libsscronet.so" "liblogifier_retrieval.so" "libsimplelog.so")
# 供体 resources/app/modules/ 下携带 linux .so / ELF 的子目录（实测四件）
readonly DONOR_MODULE_DIRS=("ai-agent" "ckg" "sandbox" "browser-bridge")
# deb 内供体布局：usr/share/<pkg>/（trae-cn 实测；按含 resources/app 自动探测兜底）
DONOR_ROOT=""

dmg_path="${TRAEWORK_DMG_PATH:-}"
electron_zip_source="${TRAEWORK_ELECTRON_ZIP_SOURCE:-}"
donor_source="${TRAEWORK_DONOR_SOURCE:-}"
nsbox_source="${TRAEWORK_NSBOX_DIR:-}"
dry_run=0
no_native=0
no_stub=0
uninstall=0
purge_data=0
assume_yes=0

usage() {
  cat <<'EOF'
用法：traework-desktop.sh [选项]

把 TraeWork_CN-darwin-arm64.dmg（VSCode 1.107.1 fork + Electron 39.2.7 定制分支）
移植为可在本机 Linux arm64 运行的自包含应用目录。

选项：
  --dir DIR          安装目录（默认：$TOOLS_HOME/traework-desktop）
  --dmg FILE         指定 DMG（默认扫描 /sdcard/Download/TraeWork*.dmg）
  --electron-zip F   指定 electron-v*-linux-arm64.zip（默认自动扫描/下载）
  --donor FILE       Trae CN linux-arm64 官方包（deb/tar.gz，推荐）：整套运行时 +
                     纯 JS 闭源模块 + 预编译 .node + modules/*.so + rg/fd 供体回填
  --nsbox [DIR]      用 nsbox 替换 modules/sandbox/trae-sandbox（chroot 环境必需：
                     官方沙箱依赖 bwrap/user-namespace 无法在 chroot 运行）。
                     DIR 为 new-trae-sandbox 模块目录（含 nsbox.go / nsbox），
                     缺省自动探测 ~/new-trae-sandbox
  --no-native        跳过原生模块重编（快速验证主进程是否可启动）
  --no-stub          不为闭源 darwin 模块生成 stub（默认生成）
  --uninstall        删除安装目录、构建缓存；--purge-data 一并删运行数据
  --yes              卸载时不询问
  --dry-run          只打印将执行的阶段
  -h, --help         显示帮助

环境变量：
  TRAEWORK_DMG_PATH / TRAEWORK_ELECTRON_ZIP_SOURCE / TRAEWORK_DONOR_SOURCE
  TRAEWORK_NSBOX_DIR           等效 --nsbox DIR
  TRAEWORK_ELECTRON_VERSION   覆盖自动探测的 Electron 版本（如 39.2.7）
  ELECTRON_MIRROR / ELECTRON_HEADERS_URL / MAX_BUILD_THREADS
EOF
}

die() { printf '错误：%s\n' "$*" >&2; exit 1; }
info() { printf '\n==> %s\n' "$*" >&2; }
warn() { printf '警告：%s\n' "$*" >&2; }

# ---------- /sdcard/Download 自动发现 ----------
find_downloaded_file() (
  local pattern="$1" candidate newest=""
  local -a candidates
  shopt -s nullglob nocaseglob
  candidates=("$DOWNLOAD_DIR"/$pattern)
  for candidate in "${candidates[@]}"; do
    if [[ -z "$newest" || "$candidate" -nt "$newest" ]]; then
      newest="$candidate"
    fi
  done
  printf "%s" "$newest"
)

find_seven_zip() {
  local cmd
  for cmd in 7zz 7z 7za; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf "%s" "$cmd"
      return 0
    fi
  done
  return 1
}

# ---------- 阶段 1：解包 DMG（参照 codex dmg.sh 的 -snl + 软链修复） ----------
repair_7z_dangerous_link_path_warnings() {
  local extract_dir="$1" app_dir="$2" seven_log="$3"
  local repaired=0 failed=0 line payload link_rel link_target link_path app_root
  app_root=$(realpath -m "$app_dir")
  while IFS= read -r line; do
    case "$line" in
      "ERROR: Dangerous link path was ignored : "*)
        payload="${line#ERROR: Dangerous link path was ignored : }"
        link_rel="${payload% : *}"
        link_target="${payload##* : }"
        if [[ -z "$link_rel" || -z "$link_target" || "$link_target" == /* ]]; then
          failed=$((failed + 1))
          continue
        fi
        link_path="$extract_dir/$link_rel"
        case "$(realpath -m "$link_path")" in
          "$app_root"|"$app_root"/*) ;;
          *) failed=$((failed + 1)); continue ;;
        esac
        rm -f "$link_path" 2>/dev/null || true
        if ln -s "$link_target" "$link_path" 2>/dev/null; then
          repaired=$((repaired + 1))
        else
          failed=$((failed + 1))
        fi
        ;;
    esac
  done <"$seven_log"
  if ((repaired > 0)); then
    info "已修复 $repaired 条被 7z 忽略的软链"
  fi
  if ((failed > 0)); then
    warn "有 $failed 条软链修复失败，若启动报缺文件请回查 $seven_log"
  fi
}

extract_dmg() {
  local dmg="$1" seven_zip extract_dir seven_log status=0 app_dir
  seven_zip=$(find_seven_zip) || die "缺少 p7zip（7z/7zz/7za），请先安装。"
  extract_dir="$WORK_DIR/dmg-extract"
  seven_log="$WORK_DIR/7z.log"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"
  info "用 $seven_zip 解包 DMG（-snl 保留软链）..."
  "$seven_zip" x -y -snl "$dmg" -o"$extract_dir" >"$seven_log" 2>&1 || status=$?
  app_dir=$(find "$extract_dir" -maxdepth 3 -name "*.app" -type d | head -1)
  if [[ -z "$app_dir" ]]; then
    cat "$seven_log" >&2
    die "DMG 内未找到 .app 包"
  fi
  if ((status != 0)); then
    repair_7z_dangerous_link_path_warnings "$extract_dir" "$app_dir" "$seven_log"
  fi
  info "找到应用包：$(basename "$app_dir")"
  printf "%s" "$app_dir"
}

# ---------- 阶段 2：探测 Electron 版本（定制 fork → 取主线 semver） ----------
detect_electron_version() {
  local app_dir="$1" plist_file detected
  if [[ -n "${TRAEWORK_ELECTRON_VERSION:-}" ]]; then
    ELECTRON_VERSION="$TRAEWORK_ELECTRON_VERSION"
    info "使用环境变量指定的 Electron：$ELECTRON_VERSION"
    return 0
  fi
  plist_file="$app_dir/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/Info.plist"
  detected=""
  if [[ -f "$plist_file" ]]; then
    detected=$(python3 - "$plist_file" <<'PY' 2>/dev/null || true
import plistlib, sys
with open(sys.argv[1], "rb") as f:
    pl = plistlib.load(f)
print(pl.get("CFBundleShortVersionString") or pl.get("CFBundleVersion") or "")
PY
)
  fi
  ELECTRON_VERSION=$(printf "%s" "$detected" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' || true)
  if [[ -z "$ELECTRON_VERSION" ]]; then
    die "无法从 DMG 探测 Electron 版本；请用 TRAEWORK_ELECTRON_VERSION 指定（如 39.2.7）。"
  fi
  info "探测到 Electron：${detected:-未知} → 使用官方主线 $ELECTRON_VERSION（stock 运行时）"
}

# ---------- 阶段 3：准备 Linux 运行时 ----------
# 供体模式：直接复用 deb 官方 Linux 布局整套运行时（@aha-kit/electron 39.2.7 定制分支的
# Linux arm64 构建 + GPU 库 + libaha_net/libsscronet），ABI 与 TraeWork DMG 天然同源。
prepare_runtime_from_donor() {
  info "使用 deb 供体整套 Linux 运行时（官方 @aha-kit/electron 布局）..."
  rm -rf "$APP_DIR"
  mkdir -p "$APP_DIR"
  cp -a "$DONOR_ROOT/." "$APP_DIR/"
  # 供体的 resources/app 与 bin/ 是 Trae CN 的，弃用；TraeWork 的 app 在阶段 4 放入。
  # 保留 resources/{linux/apparmor-profile,completions}（Linux 专属，无害）与 app-update.yml
  # （url 为空 = 禁自动更新，保护移植产物）。manifest.json 是 TTNet 运行时配置（定制 Electron
  # 在应用根读取，两包同源同尺寸 2134B）——先留供体版兜底，阶段 4 用 DMG 版覆盖。
  rm -rf "$APP_DIR/resources/app" "$APP_DIR/bin"
  local entry
  entry=$(find "$APP_DIR" -maxdepth 1 -type f -size +100M | head -1 || true)
  [[ -n "$entry" ]] || die "供体根目录未找到 Electron 主程序（>100MB）"
  chmod +x "$entry" "$APP_DIR/chrome-sandbox" "$APP_DIR/chrome_crashpad_handler" 2>/dev/null || true
  info "Electron 主程序：$(basename "$entry")（aha-kit 39.2.7 分支）"
}

prepare_runtime() {
  if [[ -n "$DONOR_ROOT" ]]; then
    prepare_runtime_from_donor
    return 0
  fi
  local electron_arch electron_zip url cache_dir cached_zip
  case "$(uname -m)" in
    aarch64|arm64) electron_arch=arm64 ;;
    x86_64) electron_arch=x64 ;;
    *) die "本脚本面向 linux-arm64，当前架构 $(uname -m) 需另行适配" ;;
  esac
  electron_zip="electron-v${ELECTRON_VERSION}-linux-${electron_arch}.zip"
  url="${ELECTRON_MIRROR%/}/v${ELECTRON_VERSION}/${electron_zip}"
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/traework-desktop/electron"
  mkdir -p "$cache_dir"
  cached_zip="$cache_dir/electron.zip"

  if [[ -z "$electron_zip_source" ]]; then
    electron_zip_source=$(find_downloaded_file "electron-v*-linux-${electron_arch}.zip")
  fi
  if [[ -n "$electron_zip_source" ]]; then
    [[ -f "$electron_zip_source" ]] || die "找不到 Electron ZIP：$electron_zip_source"
    info "使用本地 Electron：$electron_zip_source"
    cp "$electron_zip_source" "$cached_zip"
  elif [[ -f "$cached_zip" && ! -s "$cache_dir/$electron_zip" ]]; then
    # 之前由 --electron-zip 拷入的通用名缓存
    :
  elif [[ ! -f "$cache_dir/$electron_zip" ]]; then
    info "下载 $electron_zip（镜像 $ELECTRON_MIRROR）..."
    curl -L --fail --continue-at - --progress-bar -o "$cache_dir/$electron_zip.part" "$url" \
      || die "Electron 下载失败，请手动下载后用 --electron-zip 指定"
    mv "$cache_dir/$electron_zip.part" "$cache_dir/$electron_zip"
    cached_zip="$cache_dir/$electron_zip"
  else
    info "使用缓存 Electron：$cache_dir/$electron_zip"
    cached_zip="$cache_dir/$electron_zip"
  fi

  rm -rf "$APP_DIR"
  mkdir -p "$APP_DIR"
  (cd "$APP_DIR" && unzip -qo "$cached_zip")
  [[ -x "$APP_DIR/electron" ]] || die "Electron 运行时解包失败：缺少 $APP_DIR/electron"
  info "Linux Electron $ELECTRON_VERSION 就绪"
}

# ---------- 阶段 4：拼装 resources/app（VSCode 平铺布局，无 asar） ----------
assemble_app() {
  local app_bundle="$1" dmg_app mcp_ext
  dmg_app="$app_bundle/Contents/Resources/app"
  if [[ ! -d "$dmg_app" || ! -f "$dmg_app/product.json" ]]; then
    die "DMG 内缺少 Contents/Resources/app/product.json（非预期布局）"
  fi
  mkdir -p "$APP_DIR/resources"
  info "复制应用资源（GB 级，稍候）..."
  cp -a "$dmg_app" "$APP_DIR/resources/app"

  # TTNet 运行时清单：DMG 内位于 Electron Framework 资源目录，Linux 布局需提到应用根
  # （与二进制同目录；无供体时定制 Electron 亦按此查找）
  local fw_manifest
  fw_manifest="$app_bundle/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/manifest.json"
  if [[ -f "$fw_manifest" ]]; then
    cp "$fw_manifest" "$APP_DIR/manifest.json"
    info "已放置 DMG 版 manifest.json（TTNet 配置）到应用根"
  fi

  # 禁用捆绑 macOS 子应用的 MCP 扩展（mac-computer-use 在 Linux 无对应物）
  mcp_ext="$APP_DIR/resources/app/extensions/byted-solo.builtin-mcp"
  if [[ -d "$mcp_ext" ]]; then
    mkdir -p "$WORK_DIR/disabled-extensions"
    mv "$mcp_ext" "$WORK_DIR/disabled-extensions/"
    info "已禁用 darwin 子应用扩展 byted-solo.builtin-mcp（可后续以 ydotool 方案另建）"
  fi
}

# ---------- 阶段 5：平台补丁 ----------
apply_platform_patches() {
  local app_res="$APP_DIR/resources/app" patch_dir patch
  info "应用平台补丁..."
  node - "$app_res/product.json" <<'JS'
const fs = require("node:fs");
const file = process.argv[2];
const product = JSON.parse(fs.readFileSync(file, "utf8"));
let changed = 0;
// darwin 文件校验和在 Linux 必然失配，移除避免启动期 integrity 告警/中断
if (product.checksums) { delete product.checksums; changed++; }
fs.writeFileSync(file, JSON.stringify(product, null, 2) + "\n");
console.log(changed ? "product.json：已移除 darwin checksums" : "product.json：无需修改");
JS

  # 附加锚点补丁：把 node 脚本放到 $SCRIPT_DIR/traework-patches/*.patch.js 即被加载。
  # 契约沿用 codex：每个补丁对 minified JS 做锚点定位，未命中必须抛错 fail-fast，
  # 不留半补丁状态。P1 阶段在此目录累积 out/main.js 的 darwin 分支锚点替换。
  patch_dir="$SCRIPT_DIR/traework-patches"
  if [[ -d "$patch_dir" ]]; then
    for patch in "$patch_dir"/*.patch.js; do
      [[ -e "$patch" ]] || continue
      info "应用补丁：$(basename "$patch")"
      node "$patch" "$app_res"
    done
  else
    info "未发现 traework-patches/ 目录，跳过锚点补丁（P1 迭代点）"
  fi
}

# ---------- 阶段 6：原生模块 ----------
module_version() {
  node -p "require('$1/package.json').version" 2>/dev/null || true
}

build_native_modules() {
  local app_res="$APP_DIR/resources/app"
  local build_dir="$WORK_DIR/native-build"
  local -a rebuild_specs=() prebuild_specs=() npm_env=()
  local m ver watcher_ver rg_dst

  for m in "${REBUILD_MODULES[@]}"; do
    ver=$(module_version "$app_res/node_modules/$m")
    if [[ -z "$ver" ]]; then warn "DMG 中未找到 $m，跳过"; continue; fi
    rebuild_specs+=("$m@$ver")
    info "计划重编：$m@$ver"
  done
  for m in "${PREBUILD_MODULES[@]}"; do
    ver=$(module_version "$app_res/node_modules/$m")
    if [[ -z "$ver" ]]; then warn "DMG 中未找到 $m，跳过"; continue; fi
    prebuild_specs+=("$m@$ver")
    info "计划 prebuild：$m@$ver"
  done
  if (( ${#rebuild_specs[@]} == 0 && ${#prebuild_specs[@]} == 0 )); then
    die "未发现任何可处理的原生模块，布局异常"
  fi

  if [[ "${MAX_BUILD_THREADS:-0}" != "0" ]]; then
    npm_env=("npm_config_jobs=$MAX_BUILD_THREADS" "NPM_CONFIG_JOBS=$MAX_BUILD_THREADS" "MAKEFLAGS=-j$MAX_BUILD_THREADS")
    info "构建并发限制：$MAX_BUILD_THREADS"
  fi

  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  (cd "$build_dir" && echo '{"private":true}' > package.json)
  info "在干净目录拉取源码（--ignore-scripts）..."
  (cd "$build_dir" && npm install "electron@$ELECTRON_VERSION" "$ELECTRON_REBUILD_PACKAGE" --save-dev --ignore-scripts >&2)
  if (( ${#rebuild_specs[@]} > 0 )); then
    (cd "$build_dir" && npm install "${rebuild_specs[@]}" --ignore-scripts >&2)
    info "用 Electron 头文件编译（$ELECTRON_HEADERS_URL，${#rebuild_specs[@]} 个目标模块）..."
    env "${npm_env[@]}" \
      npm_config_disturl="$ELECTRON_HEADERS_URL" \
      NPM_CONFIG_DISTURL="$ELECTRON_HEADERS_URL" \
      node "$build_dir/node_modules/@electron/rebuild/lib/cli.js" \
      -v "$ELECTRON_VERSION" --force --dist-url "$ELECTRON_HEADERS_URL" >&2
  fi
  if (( ${#prebuild_specs[@]} > 0 )); then
    # prebuild 在重编之后安装，避免被 electron-rebuild 从源码强编
    (cd "$build_dir" && npm install "${prebuild_specs[@]}" --ignore-scripts >&2)
    watcher_ver=$(module_version "$app_res/node_modules/@parcel/watcher")
    if [[ -n "$watcher_ver" ]]; then
      (cd "$build_dir" && npm install "@parcel/watcher-linux-arm64@$watcher_ver" --ignore-scripts >&2)
    fi
  fi

  info "回填编译产物..."
  local dest_parent
  for m in "${REBUILD_MODULES[@]}" "${PREBUILD_MODULES[@]}"; do
    [[ -d "$build_dir/node_modules/$m" ]] || continue
    dest_parent="$app_res/node_modules/$(dirname "$m")"
    mkdir -p "$dest_parent"
    rm -rf "$app_res/node_modules/$m"
    cp -r "$build_dir/node_modules/$m" "$app_res/node_modules/$m"
  done
  if [[ -d "$build_dir/node_modules/@parcel/watcher-linux-arm64" ]]; then
    rm -rf "$app_res/node_modules/@parcel/watcher-linux-arm64"
    cp -r "$build_dir/node_modules/@parcel/watcher-linux-arm64" "$app_res/node_modules/@parcel/watcher-linux-arm64"
    info "@parcel/watcher-linux-arm64 prebuild 已就位"
  fi

  # rg：用系统 ripgrep 替换 darwin 二进制（私有 @byted-fe/ripgrep 无 Linux 分发）
  rg_dst=$(find "$app_res/node_modules/@byted-fe/ripgrep" -type f -name rg 2>/dev/null | head -1 || true)
  if [[ -n "$rg_dst" ]] && command -v rg >/dev/null 2>&1; then
    cp "$(command -v rg)" "$rg_dst"
    info "rg 已替换为系统 $(rg --version | head -1)"
  else
    warn "未替换 rg（缺系统 ripgrep 或路径变化），内置搜索可能不可用"
  fi
}

# ---------- 供体提取：Trae CN linux-arm64 官方包（deb / tar.gz） ----------
extract_donor() {
  local donor="$1" donor_dir="$WORK_DIR/donor" seven_zip tmp
  rm -rf "$donor_dir"
  mkdir -p "$donor_dir"
  case "$donor" in
    *.deb)
      if command -v dpkg-deb >/dev/null 2>&1; then
        dpkg-deb -x "$donor" "$donor_dir"
      else
        seven_zip=$(find_seven_zip) || die "解 deb 需要 dpkg-deb 或 7z"
        tmp="$WORK_DIR/donor-deb"
        rm -rf "$tmp"
        mkdir -p "$tmp"
        (cd "$tmp" && "$seven_zip" x -y "$donor" >/dev/null)
        (cd "$tmp" && "$seven_zip" x -y data.tar.xz >/dev/null 2>&1 || true)
        (cd "$tmp" && "$seven_zip" x -y data.tar.zst >/dev/null 2>&1 || true)
        (cd "$tmp" && "$seven_zip" x -y data.tar.gz >/dev/null 2>&1 || true)
        find "$tmp" -maxdepth 1 -name 'data.tar*' -exec tar -xf {} -C "$donor_dir" \;
      fi
      ;;
    *.tar.gz|*.tgz)
      tar -xzf "$donor" -C "$donor_dir"
      ;;
    *)
      die "不支持的供体格式（请用 deb 或 tar.gz）：$donor"
      ;;
  esac
  # 定位应用根（deb: usr/share/<pkg>/；tar.gz 可能直接就是根）
  DONOR_ROOT=$(find "$donor_dir" -maxdepth 4 -type d -path '*/resources' -name resources 2>/dev/null \
    | while read -r r; do [[ -d "$(dirname "$r")/app" || -d "$r/app" ]] && dirname "$r" && break; done | head -1)
  if [[ -z "$DONOR_ROOT" || ! -d "$DONOR_ROOT/resources/app" ]]; then
    die "供体包内未找到 Linux 应用根目录（应含 resources/app）"
  fi
  info "供体应用根：$DONOR_ROOT"
  printf "%s" "$donor_dir"
}

write_stub_module() {
  local dest="$1" name="$2" version="$3"
  mkdir -p "$dest"
  cat >"$dest/package.json" <<EOF
{
  "name": "$name",
  "version": "${version:-0.0.0}",
  "main": "index.js",
  "private": true
}
EOF
  cat >"$dest/index.js" <<'EOF'
"use strict";
// Linux 移植 stub：无供体时的降级回退，导出全吞咽 Proxy 使上层功能降级。
// 有 deb 供体时不会走到这里 —— 官方 Linux 包内这些模块本来就是纯 JS loader。
const stub = new Proxy(function stub() { return stub; }, {
  apply: () => stub,
  construct: () => stub,
  get: (target, key) => {
    if (key === Symbol.toPrimitive) return () => "";
    if (key === "then") return undefined; // 避免 await 卡死
    return stub;
  },
});
module.exports = stub;
EOF
  info "已生成 stub：$name"
}

copy_donor_package() {
  local pkg="$1" src_parent="$DONOR_ROOT/resources/app/node_modules/$(dirname "$pkg")"
  local dst_parent="$APP_DIR/resources/app/node_modules/$(dirname "$pkg")"
  [[ -d "$DONOR_ROOT/resources/app/node_modules/$pkg" ]] || return 1
  mkdir -p "$dst_parent"
  rm -rf "$dst_parent/$(basename "$pkg")"
  cp -r "$DONOR_ROOT/resources/app/node_modules/$pkg" "$dst_parent/$(basename "$pkg")"
  return 0
}

# ---------- 供体覆盖层：官方 Linux 布局照搬 ----------
apply_donor_overlays() {
  local app_res="$APP_DIR/resources/app" pkg lib mod_dir ok_cnt=0 miss_cnt=0

  # 1. 闭源私有包：deb 内为纯 JS loader（trae-macos-native 官方自带非 darwin 空实现）
  for pkg in "${DONOR_JS_PACKAGES[@]}"; do
    if copy_donor_package "$pkg"; then
      info "覆盖（deb 纯 JS loader）：$pkg"
      ((ok_cnt++)) || true
    else
      warn "供体缺包：$pkg"
      ((miss_cnt++)) || true
    fi
  done

  # 2. rg / fd：deb 内现成 linux-arm64 ELF
  for pkg in "${DONOR_TOOL_PACKAGES[@]}"; do
    if copy_donor_package "$pkg"; then
      info "回填（linux-arm64 ELF）：$pkg"
      ((ok_cnt++)) || true
    else
      warn "供体缺工具包：$pkg"
      ((miss_cnt++)) || true
    fi
  done
  # 让 @byted-fe/ripgrep 主包的 postinstall 别名逻辑命中本地变体：把 rg 软链到 bin/
  if [[ -d "$app_res/node_modules/@byted-fe/ripgrep-linux-arm64/bin" ]]; then
    local rg_main="$app_res/node_modules/@byted-fe/ripgrep/bin"
    if [[ -d "$rg_main" ]]; then
      cp "$app_res/node_modules/@byted-fe/ripgrep-linux-arm64/bin/rg" "$rg_main/rg" 2>/dev/null || true
      info "rg 主包 bin/ 已同步 linux-arm64 二进制"
    fi
  fi

  # 3. 开源模块预编译 .node：整树覆盖，跳过 electron-rebuild（ABI 同为 aha-kit 39.2.7）
  #    deb 实测仅预编译 4 件；watchdog/keymap/is-elevated 官方 Linux 即不带（见文件头注释）
  for pkg in "${DONOR_PREBUILD_PACKAGES[@]}"; do
    if copy_donor_package "$pkg"; then
      info "覆盖（deb 预编译）：$pkg"
      ((ok_cnt++)) || true
    else
      warn "供体缺预编译模块：$pkg"
      ((miss_cnt++)) || true
    fi
  done
  for pkg in "${DONOR_ABSENT_MODULES[@]}"; do
    if [[ -d "$app_res/node_modules/$pkg" ]]; then
      rm -rf "$app_res/node_modules/$pkg"
      info "移除官方 Linux 不携带的模块（darwin 残留）：$pkg"
    fi
  done

  # 4. modules/ 原生库：ckg / ai-agent / sandbox / browser-bridge（main.js 按 platform 自动选 .so 文件名）
  for mod_dir in "${DONOR_MODULE_DIRS[@]}"; do
    if [[ -d "$DONOR_ROOT/resources/app/modules/$mod_dir" ]]; then
      mkdir -p "$app_res/modules"
      rm -rf "$app_res/modules/$mod_dir"
      cp -r "$DONOR_ROOT/resources/app/modules/$mod_dir" "$app_res/modules/$mod_dir"
      info "回填 modules/$mod_dir（含 linux .so）"
    else
      warn "供体缺 modules/$mod_dir"
    fi
  done

  # 5. 应用根目录网络栈 .so（libaha_net → libsscronet 依赖链）
  for lib in "${DONOR_ROOT_LIBS[@]}"; do
    if [[ -f "$DONOR_ROOT/$lib" ]]; then
      cp "$DONOR_ROOT/$lib" "$APP_DIR/"
    fi
  done
  info "根目录 .so 回填完成：${DONOR_ROOT_LIBS[*]}"

  info "供体覆盖完成（成功 $ok_cnt 项，缺失 $miss_cnt 项）"
  ((miss_cnt == 0)) || warn "存在缺失项；如启动报缺模块可补充供体或手工回填"
}

# 无供体时的回退：stub 闭源模块（功能降级但可启动）
handle_closed_modules_fallback() {
  local app_res="$APP_DIR/resources/app" m v
  warn "无 deb 供体：闭源模块走 stub 降级（AI 网络栈/性能 SDK 相关功能将不可用）"
  for m in "@aha-kit/ipc" "@aha-kit/net" "@aha-kit/perf-sdk" "@byted-icube/trae-network-client"; do
    if ((no_stub == 1)); then
      warn "跳过 stub（--no-stub）：$m"
      continue
    fi
    v=$(module_version "$app_res/node_modules/$m" || module_version "$app_res/node_modules/${m}-darwin-arm64" || true)
    write_stub_module "$app_res/node_modules/$m" "$m" "$v"
  done
  # trae-macos-native：DMG 内版本 require 后即用，非 darwin 导出空实现由 deb 版提供；
  # 无供体时 stub 之
  if ((no_stub == 0)); then
    v=$(module_version "$app_res/node_modules/@byted-icube/trae-macos-native" || true)
    write_stub_module "$app_res/node_modules/@byted-icube/trae-macos-native" "@byted-icube/trae-macos-native" "$v"
  fi
}

# ---------- 阶段 6.5：nsbox 沙箱替换（chroot 环境必需） ----------
# 官方 modules/sandbox/trae-sandbox 基于 bwrap/user-namespace，在 chroot（无
# CAP_SYS_ADMIN / 无 unprivileged userns）中无法运行；nsbox（~/new-trae-sandbox）
# 提供 trae-sandbox 兼容 CLI（exec --storage-path/--config-name/--shell-path/
# --command-line）的无沙箱直通实现，替换后终端/命令执行功能恢复。
resolve_nsbox_dir() {
  local candidate
  if [[ "$nsbox_source" != "auto" ]]; then
    printf "%s" "$nsbox_source"
    return 0
  fi
  for candidate in "$HOME/new-trae-sandbox" "$SCRIPT_DIR/../new-trae-sandbox"; do
    if [[ -f "$candidate/nsbox.go" || -f "$candidate/nsbox" ]]; then
      printf "%s" "$candidate"
      return 0
    fi
  done
  return 1
}

apply_nsbox_replacement() {
  local sandbox_dir="$APP_DIR/resources/app/modules/sandbox"
  local nsbox_dir src bin
  [[ -d "$sandbox_dir" ]] || die "--nsbox：未找到 $sandbox_dir（modules/sandbox 应由 DMG/供体提供）"
  nsbox_dir=$(resolve_nsbox_dir) || die "--nsbox：找不到 new-trae-sandbox 目录，请用 --nsbox DIR 指定"
  [[ -d "$nsbox_dir" ]] || die "--nsbox：目录不存在：$nsbox_dir"
  src="$nsbox_dir/nsbox.go"
  bin="$nsbox_dir/nsbox"
  # 源码比二进制新则重编（无 go 且二进制可用时直接用现成二进制）
  if [[ -f "$src" && ( ! -x "$bin" || "$src" -nt "$bin" ) ]]; then
    if command -v go >/dev/null 2>&1; then
      info "编译 nsbox（trae-sandbox 兼容直通执行器）..."
      (cd "$nsbox_dir" && go build -o nsbox nsbox.go) || die "nsbox 编译失败"
    elif [[ ! -x "$bin" ]]; then
      die "--nsbox：$nsbox_dir 下无预编译 nsbox 二进制，且缺少 go 工具链无法编译 nsbox.go"
    fi
  fi
  [[ -x "$bin" ]] || die "--nsbox：nsbox 二进制不存在或不可执行：$bin"
  if [[ -f "$sandbox_dir/trae-sandbox" && ! -f "$sandbox_dir/trae-sandbox.orig" ]]; then
    mv "$sandbox_dir/trae-sandbox" "$sandbox_dir/trae-sandbox.orig"
    info "已备份官方沙箱二进制：modules/sandbox/trae-sandbox.orig"
  fi
  rm -f "$sandbox_dir/trae-sandbox"
  cp "$bin" "$sandbox_dir/trae-sandbox"
  chmod 0755 "$sandbox_dir/trae-sandbox"
  info "已替换 trae-sandbox → nsbox（chroot 直通执行，接口兼容；恢复请用 trae-sandbox.orig）"
}

# ---------- 阶段 7：启动器 ----------
generate_launcher() {
  cat >"$APP_DIR/start.sh" <<'LAUNCHER'
#!/bin/bash
set -Eeuo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ID="trae-solo-cn"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$APP_ID"
export CHROME_DESKTOP="${CHROME_DESKTOP:-${APP_ID}.desktop}"

if [[ "${1:-}" == "--diagnose" ]]; then
  failed=0
  ELECTRON_BIN=""
  for cand in "$APP_DIR/electron" "$APP_DIR/trae-cn" "$(find "$APP_DIR" -maxdepth 1 -type f -size +100M 2>/dev/null | head -1)"; do
    if [[ -x "$cand" || -f "$cand" ]]; then ELECTRON_BIN="$cand"; break; fi
  done
  if [[ -n "$ELECTRON_BIN" ]]; then
    printf 'ok: %s\n' "$ELECTRON_BIN"
  else
    printf 'missing: Electron 主程序（electron / trae-cn）\n'; failed=1
  fi
  for f in "$APP_DIR/resources/app/product.json" "$APP_DIR/resources/app/out/main.js" \
           "$APP_DIR/libaha_net.so" "$APP_DIR/libsscronet.so"; do
    if [[ -e "$f" ]]; then printf 'ok: %s\n' "$f"; else printf 'missing: %s\n' "$f"; fi
  done
  while IFS= read -r -d '' so; do
    if head -c4 "$so" 2>/dev/null | od -An -tx1 | grep -q '7f 45 4c 46'; then
      printf 'ok(ELF): %s\n' "$so"
    else
      printf 'NOT-ELF: %s（仍为 darwin 二进制，对应功能不可用）\n' "$so"
      failed=1
    fi
  done < <(find "$APP_DIR/resources/app/node_modules" -name '*.node' -print0 2>/dev/null)
  while IFS= read -r -d '' so; do
    if head -c4 "$so" 2>/dev/null | od -An -tx1 | grep -q '7f 45 4c 46'; then
      printf 'ok(ELF): %s\n' "$so"
    else
      printf 'NOT-ELF: %s\n' "$so"
    fi
  done < <(find "$APP_DIR/resources/app/modules" -name '*.so' -print0 2>/dev/null)
  exit "$failed"
fi

mkdir -p "$STATE_DIR" 2>/dev/null || true
FLAGS_FILE="$APP_DIR/electron-flags.conf"
EXTRA_FLAGS=()
if [[ -r "$FLAGS_FILE" ]]; then
  mapfile -t EXTRA_FLAGS < <(grep -v '^[[:space:]]*#' "$FLAGS_FILE" || true)
fi

ELECTRON_BIN=""
for cand in "$APP_DIR/electron" "$APP_DIR/trae-cn" "$(find "$APP_DIR" -maxdepth 1 -type f -size +100M 2>/dev/null | head -1)"; do
  if [[ -x "$cand" || -f "$cand" ]]; then ELECTRON_BIN="$cand"; break; fi
done
[[ -n "$ELECTRON_BIN" ]] || { echo "错误：未找到 Electron 主程序" >&2; exit 1; }

# proot/chroot 环境通常无 user namespaces，默认关沙箱；Wayland 可在 flags 文件加
# --ozone-platform=wayland 切换。
exec "$ELECTRON_BIN" --no-sandbox "${EXTRA_FLAGS[@]}" "$@"
LAUNCHER
  chmod +x "$APP_DIR/start.sh"

  local desktop_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  mkdir -p "$desktop_dir"
  cat >"$desktop_dir/$APP_ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_DISPLAY_NAME
Exec=$APP_DIR/start.sh
Terminal=false
Categories=Development;
StartupWMClass=TRAE SOLO CN
EOF
  info "启动器：$APP_DIR/start.sh（--diagnose 自检可用）"
}

configure_root_runtime() {
  mkdir -p "$DATA_DIR"
  local line
  local config_lines=(
    "export TRAEWORK_DATA_DIR=$DATA_DIR"
    "alias trae-desktop-local=\"$APP_DIR/start.sh --user-data-dir $DATA_DIR\""
  )
  for line in "${config_lines[@]}"; do
    grep -Fqx "$line" "$TOOLSRC" 2>/dev/null || printf "%s\n" "$line" >>"$TOOLSRC"
  done
  info "已写入用户配置：$TOOLSRC"
}

# ---------- 卸载 ----------
uninstall_traework() {
  local -a targets=("$install_dir" "${XDG_CACHE_HOME:-$HOME/.cache}/traework-desktop")
  local answer t
  if ((assume_yes == 0)); then
    printf '将删除以下目录：\n'
    printf '  - %s\n  - %s\n' "${targets[0]}" "${targets[1]}"
    if ((purge_data == 1)); then
      printf '同时删除运行数据：\n  - %s\n  - %s\n' "$DATA_DIR" "${XDG_CONFIG_HOME:-$HOME/.config}/$APP_ID"
    else
      printf '运行数据将保留；如需删除请加 --purge-data。\n'
    fi
    read -r -p '确认继续？[y/N] ' answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      info '已取消'
      return 0
    fi
  fi
  pkill -f "$install_dir" 2>/dev/null || true
  for t in "${targets[@]}"; do
    if [[ -n "$t" && "$t" != "/" && -e "$t" ]]; then
      info "删除：$t"
      rm -rf -- "$t"
    fi
  done
  if ((purge_data == 1)); then
    for t in "$DATA_DIR" "${XDG_CONFIG_HOME:-$HOME/.config}/$APP_ID"; do
      if [[ -e "$t" ]]; then
        info "删除运行数据：$t"
        rm -rf -- "$t"
      fi
    done
  fi
  if [[ -f "$TOOLSRC" ]]; then
    sed -i -e '/^export TRAEWORK_DATA_DIR=/d' -e '/^alias trae-desktop-local=/d' "$TOOLSRC"
  fi
  rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/$APP_ID.desktop"
  info '卸载完成；/sdcard/Download 下的 DMG/Electron/供体包均已保留'
}

# ---------- 参数解析 ----------
while (($#)); do
  case "$1" in
    --dir) (($# >= 2)) || die "--dir 需要一个目录"; install_dir=$2; shift 2 ;;
    --dmg) (($# >= 2)) || die "--dmg 需要一个文件路径"; dmg_path=$2; shift 2 ;;
    --electron-zip) (($# >= 2)) || die "--electron-zip 需要一个文件路径"; electron_zip_source=$2; shift 2 ;;
    --donor) (($# >= 2)) || die "--donor 需要一个文件路径"; donor_source=$2; shift 2 ;;
    --nsbox)
      nsbox_source="auto"
      if [[ $# -ge 2 && "${2:-}" != -* ]]; then nsbox_source=$2; shift; fi
      shift ;;
    --no-native) no_native=1; shift ;;
    --no-stub) no_stub=1; shift ;;
    --uninstall) uninstall=1; shift ;;
    --purge-data) purge_data=1; shift ;;
    --yes) assume_yes=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知选项：$1（使用 --help 查看帮助）" ;;
  esac
done

readonly APP_DIR="$install_dir/app"
readonly WORK_DIR="$install_dir/build"

if ((uninstall == 1)); then
  if ((dry_run == 1)); then
    printf '预览：卸载 %s 与构建缓存' "$install_dir"
    if ((purge_data == 1)); then printf '，并删除运行数据'; fi
    printf '\n'
    exit 0
  fi
  uninstall_traework
  exit 0
fi
if ((purge_data != 0)); then die '--purge-data 只能与 --uninstall 一起使用'; fi
if ((assume_yes != 0)); then die '--yes 只能与 --uninstall 一起使用'; fi

# ---------- 预检 ----------
for cmd in node npm python3 unzip curl; do
  command -v "$cmd" >/dev/null || die "缺少 $cmd，请先安装。"
done
node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 20 ? 0 : 1)' \
  || die "需要 Node.js >= 20"

if [[ -z "$dmg_path" ]]; then
  dmg_path=$(find_downloaded_file "TraeWork*.dmg")
  if [[ -z "$dmg_path" ]]; then
    dmg_path=$(find_downloaded_file "*.dmg")
  fi
fi
if [[ -z "$dmg_path" ]]; then
  die "未找到 DMG；请用 --dmg 指定 TraeWork_CN-darwin-arm64.dmg 路径"
fi
[[ -f "$dmg_path" ]] || die "找不到 DMG：$dmg_path"
dmg_path=$(realpath "$dmg_path")
info "使用 DMG：$dmg_path"

if [[ -z "$donor_source" ]]; then
  donor_source=$(find_downloaded_file "Trae_CN-linux-arm64.*")
  if [[ -z "$donor_source" ]]; then
    donor_source=$(find_downloaded_file "*linux-arm64.deb")
  fi
fi
if [[ -n "$donor_source" ]]; then
  [[ -f "$donor_source" ]] || die "找不到供体包：$donor_source"
  donor_source=$(realpath "$donor_source")
  info "使用供体：$donor_source（Trae CN linux-arm64 官方包）"
else
  warn "未指定 --donor：将退回 stock Electron + npm 重编 + stub 降级路线"
fi

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  info "目标环境：${PRETTY_NAME:-Linux}（$(uname -m)）"
fi

if ((dry_run == 1)); then
  if [[ -n "$donor_source" ]]; then
    runtime_plan="deb 供体整套运行时（@aha-kit/electron 39.2.7 Linux arm64）"
    native_plan="供体覆盖：纯 JS 闭源包 + 预编译 .node + modules/*.so + rg/fd（跳过重编）"
  else
    runtime_plan="${electron_zip_source:-自动下载/缓存 stock zip}（镜像 $ELECTRON_MIRROR）"
    native_plan="npm 重编 ${#REBUILD_MODULES[@]} 个模块 + prebuild + stub 降级"
  fi
  if ((no_native == 1)); then native_plan="跳过（--no-native，仅主进程冒烟）"; fi
  nsbox_plan="保留官方 trae-sandbox"
  if [[ -n "$nsbox_source" ]]; then nsbox_plan="nsbox 替换 modules/sandbox/trae-sandbox（chroot 直通）"; fi
  cat <<EOF
预览（--dry-run）：
  1. 解包 DMG            $dmg_path
  2. 探测 Electron       自动（可 TRAEWORK_ELECTRON_VERSION 覆盖）
  3. Linux 运行时        $runtime_plan
  4. 拼装应用            $APP_DIR/resources/app
  5. 平台补丁            product.json + traework-patches/*.patch.js
  6. 原生模块            $native_plan
  6.5 沙箱替换           $nsbox_plan
  7. 启动器              $APP_DIR/start.sh
EOF
  exit 0
fi

# ---------- 主流程 ----------
mkdir -p "$WORK_DIR"
if [[ -n "$donor_source" ]]; then
  extract_donor "$donor_source" >/dev/null
fi
app_bundle=$(extract_dmg "$dmg_path")
detect_electron_version "$app_bundle"
prepare_runtime
assemble_app "$app_bundle"
apply_platform_patches
if ((no_native == 1)); then
  warn "--no-native：跳过原生模块处置，darwin .node 加载将失败（仅用于主进程冒烟验证）"
elif [[ -n "$DONOR_ROOT" ]]; then
  apply_donor_overlays
else
  build_native_modules
  handle_closed_modules_fallback
fi
if [[ -n "$nsbox_source" ]]; then
  apply_nsbox_replacement
fi
generate_launcher
configure_root_runtime

info "移植完成。验证顺序："
printf '  1) %s/start.sh --diagnose\n' "$APP_DIR"
printf '  2) %s/start.sh\n' "$APP_DIR"
printf '  3) 观察登录页 → 打开工作区 → 触发搜索/终端（覆盖 watcher、node-pty、rg）\n'
