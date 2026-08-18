#!/usr/bin/env bash
set -Eeuo pipefail

# WorkBuddy（@genie/workbuddy-desktop）macOS DMG → Linux arm64 移植脚本
#
# 仿照本目录 traework-desktop.sh 的结构（中文提示、die/info/warn、/sdcard/Download
# 扫描、toolsinit 集成、start.sh 启动器），但走 codex 式 stock Electron 管线。
# 完整取证见 ~/sh/workbuddy-port-report/workbuddy-port-report.html。
#
# 供体实测结论（2026-08-18，WorkBuddy-darwin-arm64-5.3.13.35923969-20fd9da5.dmg）：
#   标准 electron-builder 打包：主程序 MacOS/Electron（stock 标志）、Squirrel 更新、
#   Electron Framework 37.10.3（注意 ShortVersionString 为空，须读 CFBundleVersion）。
#   app.asar 283MB + app.asar.unpacked（.node 全部 unpacked）。
#   原生模块全部零编译可解决：
#     - koffi 2.16.2 / cli/vendor/ripgrep：包内自带 linux_arm64 ELF，无需处理
#     - node-pty 1.1.0：npm 取 @lydell/node-pty-linux-arm64（NAPI，ABI 无关），
#       pty.node 放 node-pty/prebuilds/linux-arm64/ + 变体包同级双保险
#     - better-sqlite3 12.8.0：GitHub 官方 prebuild（electron ABI v136 =
#       bin/darwin-arm64-136 目录名推导），放 build/Release 与 bin/linux-arm64-<abi>/
#     - fsevents / qimei / wechat-copydata-decoder：主进程自带守卫
#       （isSupported/try-catch/条件展开），Linux 下自动降级；--stub-telemetry 可 stub qimei
#   无定制运行时 / 无闭源网络栈 .so / 无自定义沙箱 → 不需要 deb 供体与 nsbox。
#
# 管线：解包 DMG → 探测 Electron 版本 → stock Electron zip → asar 解包为平铺
#       resources/app → 原生模块下载回填 → start.sh 启动器
#
# 用法示例：
#   ./workbuddy-desktop.sh                                  # 扫描 /sdcard/Download 自动发现
#   ./workbuddy-desktop.sh --dmg /sdcard/Download/WorkBuddy-darwin-arm64-*.dmg
#   ./workbuddy-desktop.sh --stub-telemetry                 # qimei 一键 stub（冒烟失败时）
#   ./workbuddy-desktop.sh --dry-run
#   ./workbuddy-desktop.sh --uninstall [--purge-data --yes]

readonly SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
readonly TOOLSINIT="${TOOLSINIT:-${SCRIPT_DIR}/toolsinit.sh}"
[[ -r "$TOOLSINIT" ]] || { echo "错误：找不到 toolsinit.sh：$TOOLSINIT" >&2; exit 1; }
PREFIX="${PREFIX:-}"
TMPDIR="${TMPDIR:-}"
. "$TOOLSINIT"
TOOLSRC_NAME=workbuddyrc
TOOLSRC=$(toolsRC "$TOOLSRC_NAME")
TOOLS_HOME=$(install_path)

readonly APP_ID="workbuddy"
readonly APP_DISPLAY_NAME="WorkBuddy"
install_dir="${WORKBUDDY_INSTALL_DIR:-${TOOLS_HOME}/workbuddy-desktop}"
DATA_DIR="${WORKBUDDY_DATA_DIR:-${TOOLS_HOME}/workbuddy-desktop-data}"
readonly DOWNLOAD_DIR="/sdcard/Download"
readonly ELECTRON_MIRROR="${ELECTRON_MIRROR:-https://npmmirror.com/mirrors/electron/}"
readonly BS3_RELEASE_BASE="${WORKBUDDY_BS3_BASE:-https://github.com/WiseLibs/better-sqlite3/releases/download}"
# better-sqlite3 官方 prebuild 下载直连失败时的镜像（gitee/ghproxy 等可自行覆盖）
readonly GH_DL_PROXY="${WORKBUDDY_GH_PROXY:-}"

dmg_path="${WORKBUDDY_DMG_PATH:-}"
electron_zip_source="${WORKBUDDY_ELECTRON_ZIP_SOURCE:-}"
stub_telemetry=0
dry_run=0
no_native=0
uninstall=0
purge_data=0
assume_yes=0

usage() {
  cat <<'EOF'
用法：workbuddy-desktop.sh [选项]

把 WorkBuddy-darwin-arm64.dmg（stock Electron 37.10.3 + electron-builder）
移植为可在本机 Linux arm64 运行的自包含应用目录。零编译：原生模块全部
来自官方预编译二进制（包内自带 / npm 变体包 / GitHub prebuild）。

选项：
  --dir DIR          安装目录（默认：$TOOLS_HOME/workbuddy-desktop）
  --dmg FILE         指定 DMG（默认扫描 /sdcard/Download/WorkBuddy*.dmg）
  --electron-zip F   指定 electron-v*-linux-arm64.zip（默认自动扫描/下载）
  --no-native        跳过原生模块回填（仅验证主进程是否可启动）
  --stub-telemetry   把 @tencent/qimei-node 替换为 Proxy stub（遥测降级）
  --uninstall        删除安装目录、构建缓存；--purge-data 一并删运行数据
  --yes              卸载时不询问
  --dry-run          只打印将执行的阶段
  -h, --help         显示帮助

环境变量：
  WORKBUDDY_DMG_PATH / WORKBUDDY_ELECTRON_ZIP_SOURCE / WORKBUDDY_INSTALL_DIR
  WORKBUDDY_DATA_DIR / WORKBUDDY_ELECTRON_VERSION（覆盖自动探测的 Electron 版本）
  WORKBUDDY_GH_PROXY（better-sqlite3 prebuild 下载代理前缀，拼在 github URL 前）
  WORKBUDDY_ALLOW_ELECTRON_MISMATCH=1（强制使用版本不匹配的本地 Electron zip）
  ELECTRON_MIRROR
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

is_elf() {
  [[ -f "$1" ]] && head -c4 "$1" 2>/dev/null | od -An -tx1 | grep -q '7f 45 4c 46'
}

# ---------- 阶段 1：解包 DMG（沿用 traework 的 -snl + 软链修复） ----------
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
  app_dir=$(find "$extract_dir" -maxdepth 4 -name "WorkBuddy.app" -type d | head -1)
  [[ -n "$app_dir" ]] || app_dir=$(find "$extract_dir" -maxdepth 4 -name "*.app" -type d | head -1)
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

# ---------- 阶段 2：探测 Electron 版本（本样本 ShortVersionString 为空，须读 CFBundleVersion） ----------
detect_electron_version() {
  local app_dir="$1" plist_file detected
  if [[ -n "${WORKBUDDY_ELECTRON_VERSION:-}" ]]; then
    ELECTRON_VERSION="$WORKBUDDY_ELECTRON_VERSION"
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
    die "无法从 DMG 探测 Electron 版本；请用 WORKBUDDY_ELECTRON_VERSION 指定（如 37.10.3）。"
  fi
  info "探测到 Electron：${detected:-未知} → 使用官方主线 $ELECTRON_VERSION（stock 运行时）"
}

# ---------- 阶段 3：准备 stock Linux 运行时 ----------
prepare_runtime() {
  local electron_arch electron_zip url cache_dir cached_zip
  case "$(uname -m)" in
    aarch64|arm64) electron_arch=arm64 ;;
    x86_64) electron_arch=x64 ;;
    *) die "本脚本面向 linux-arm64，当前架构 $(uname -m) 需另行适配" ;;
  esac
  electron_zip="electron-v${ELECTRON_VERSION}-linux-${electron_arch}.zip"
  url="${ELECTRON_MIRROR%/}/v${ELECTRON_VERSION}/${electron_zip}"
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/workbuddy-desktop/electron"
  mkdir -p "$cache_dir"
  cached_zip="$cache_dir/electron.zip"

  if [[ -z "$electron_zip_source" ]]; then
    # 自动扫描只认精确版本：版本不匹配会导致 better-sqlite3 等 ABI 敏感模块加载失败
    electron_zip_source=$(find_downloaded_file "electron-v${ELECTRON_VERSION}-linux-${electron_arch}.zip")
    if [[ -n "$electron_zip_source" && ! -f "$electron_zip_source" ]]; then
      # /sdcard 为 FUSE 挂载，glob 可能返回 stat 不到的幽灵路径
      warn "自动扫描结果异常：$electron_zip_source 实际不存在，改走下载"
      electron_zip_source=""
    fi
  fi
  if [[ -n "$electron_zip_source" ]]; then
    [[ -f "$electron_zip_source" ]] || die "找不到 Electron ZIP：$electron_zip_source"
    if [[ "$(basename "$electron_zip_source")" != "$electron_zip" ]]; then
      if [[ "${WORKBUDDY_ALLOW_ELECTRON_MISMATCH:-0}" == "1" ]]; then
        warn "Electron 版本不匹配：$(basename "$electron_zip_source") ≠ 应用要求的 $ELECTRON_VERSION（ABI 敏感模块大概率加载失败，已按 WORKBUDDY_ALLOW_ELECTRON_MISMATCH=1 放行）"
      else
        die "Electron 版本不匹配：$(basename "$electron_zip_source") ≠ 应用要求的 $electron_zip。请下载对应版本，或设置 WORKBUDDY_ALLOW_ELECTRON_MISMATCH=1 强制使用（原生模块可能失效）。"
      fi
    fi
    info "使用本地 Electron：$electron_zip_source"
    cp "$electron_zip_source" "$cached_zip"
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

# ---------- 阶段 4：asar 解包为平铺 resources/app ----------
# 不保留 app.asar：node-pty/better-sqlite3 需要写入 asar 头内不存在的 linux 变体文件，
# Electron 对 asar 内缺失路径无 unpacked 回退，解平铺（等价 electron-builder asar:false）最稳。
#
# 容错解包：electron-builder 裁掉了 DMG 内 unpacked 目录中其他平台的二进制，但 asar
# 头仍引用它们；extractAll 读不到外部文件会整体失败。对缺失项建空占位后重试，
# 随后 unpacked 目录整体叠加拷贝，真实文件会覆盖占位（占位仅剩其他平台无关二进制）。
assemble_app() {
  local app_bundle="$1" asar_file unpacked_dir
  asar_file="$app_bundle/Contents/Resources/app.asar"
  unpacked_dir="$app_bundle/Contents/Resources/app.asar.unpacked"
  [[ -f "$asar_file" ]] || die "DMG 内缺少 Contents/Resources/app.asar（非预期布局）"

  if [[ ! -d "$WORK_DIR/node_modules/@electron/asar" ]]; then
    info "在构建目录安装 @electron/asar..."
    (cd "$WORK_DIR" && echo '{"private":true}' > package.json)
    (cd "$WORK_DIR" && npm install @electron/asar --no-save --ignore-scripts >&2)
  fi

  cat >"$WORK_DIR/asar-extract.mjs" <<'JS'
import { extractAll } from "@electron/asar";
import fs from "node:fs";
import path from "node:path";

const [archive, dest] = process.argv.slice(2);
for (let attempt = 0; ; attempt++) {
  try {
    await extractAll(archive, dest); // v4 返回 Promise，不 await 会假成功
    process.exit(0);
  } catch (e) {
    const msg = String((e && e.message) || e);
    const missing = [...msg.matchAll(/open '([^']+)'/g)].map((m) => m[1]);
    if (!missing.length || attempt >= 20) {
      console.error(msg);
      process.exit(1);
    }
    for (const f of missing) {
      fs.mkdirSync(path.dirname(f), { recursive: true });
      fs.writeFileSync(f, Buffer.alloc(0));
    }
    console.error(`asar: ${missing.length} 个 unpacked 外部文件缺失（多为其他平台二进制），已建占位并重试`);
  }
}
JS

  mkdir -p "$APP_DIR/resources"
  info "解包 app.asar 到平铺目录（283MB 级，稍候）..."
  node "$WORK_DIR/asar-extract.mjs" "$asar_file" "$APP_DIR/resources/app" \
    || die "asar 解包失败"
  # 双保险：unpacked 文件叠加拷贝，真实内容覆盖上面的占位空文件
  if [[ -d "$unpacked_dir" ]]; then
    cp -a "$unpacked_dir/." "$APP_DIR/resources/app/"
  fi
  [[ -f "$APP_DIR/resources/app/main/index.js" ]] || die "asar 解包异常：缺少 main/index.js"
  info "resources/app 就绪（平铺布局，共 $(find "$APP_DIR/resources/app" -type f | wc -l) 个文件）"
}

# ---------- 阶段 5：原生模块回填（全部官方预编译，零编译） ----------
backfill_native_modules() {
  local app_res="$APP_DIR/resources/app" build_dir="$WORK_DIR/native-build"
  local pkg_json ver abi tarball url dst

  # 1. koffi / ripgrep：包内自带 linux_arm64 ELF，仅校验
  if is_elf "$app_res/node_modules/koffi/build/koffi/linux_arm64/koffi.node"; then
    info "koffi：包内自带 linux_arm64 ELF ✓（win32 WM_COPYDATA 分支外不参与启动）"
  else
    warn "koffi linux_arm64 缺失或非 ELF（主进程有 win32 守卫，理论上不影响）"
  fi
  if is_elf "$app_res/cli/vendor/ripgrep/arm64-linux/ripgrep.node"; then
    info "ripgrep：包内自带 arm64-linux ELF ✓"
  elif is_elf /usr/bin/rg; then
    mkdir -p "$app_res/cli/vendor/ripgrep/arm64-linux"
    cp /usr/bin/rg "$app_res/cli/vendor/ripgrep/arm64-linux/rg"
    info "ripgrep：arm64-linux/rg 已用系统 ripgrep 回填 ✓（ripgrep.node NAPI 变体仍缺失，如搜索异常再处理）"
  else
    warn "ripgrep arm64-linux 缺失且系统无 /usr/bin/rg，内置搜索可能不可用（apt 安装 ripgrep 后重跑即可回填）"
  fi

  # 2. node-pty：取 @lydell linux-arm64 变体包（NAPI，ABI 无关）
  local pty_var_ver
  pty_var_ver=$(node -p "require('$app_res/node_modules/@lydell/node-pty-darwin-arm64/package.json').version" 2>/dev/null || true)
  [[ -n "$pty_var_ver" ]] || pty_var_ver="1.2.0-beta.14"
  info "node-pty：下载 @lydell/node-pty-linux-arm64@$pty_var_ver（与包内 darwin 变体同版本）..."
  rm -rf "$build_dir"
  mkdir -p "$build_dir"
  (cd "$build_dir" && echo '{"private":true}' > package.json)
  if (cd "$build_dir" && npm install "@lydell/node-pty-linux-arm64@$pty_var_ver" --ignore-scripts >&2); then
    mkdir -p "$app_res/node_modules/node-pty/prebuilds/linux-arm64"
    cp "$build_dir/node_modules/@lydell/node-pty-linux-arm64/prebuilds/linux-arm64/pty.node" \
      "$app_res/node_modules/node-pty/prebuilds/linux-arm64/pty.node"
    rm -rf "$app_res/node_modules/@lydell/node-pty-linux-arm64"
    cp -r "$build_dir/node_modules/@lydell/node-pty-linux-arm64" \
      "$app_res/node_modules/@lydell/node-pty-linux-arm64"
    is_elf "$app_res/node_modules/node-pty/prebuilds/linux-arm64/pty.node" \
      && info "node-pty：pty.node 已回填（prebuilds/linux-arm64 + 变体包双保险）✓" \
      || warn "node-pty 回填后非 ELF，终端功能可能异常"
  else
    warn "node-pty 变体包下载失败（内置终端将不可用，主进程不受影响）"
  fi

  # 3. better-sqlite3：GitHub 官方 prebuild；ABI 从包内 darwin 目录名推导（如 darwin-arm64-136）
  pkg_json="$app_res/node_modules/better-sqlite3/package.json"
  ver=$(node -p "require('$pkg_json').version" 2>/dev/null || true)
  abi=$(basename "$(ls -d "$app_res/node_modules/better-sqlite3/bin/"darwin-* 2>/dev/null | head -1)" 2>/dev/null | grep -oE '[0-9]+$' || true)
  if [[ -z "$ver" || -z "$abi" ]]; then
    warn "better-sqlite3 版本/ABI 探测失败，跳过回填"
    return 0
  fi
  tarball="better-sqlite3-v${ver}-electron-v${abi}-linux-arm64.tar.gz"
  url="$BS3_RELEASE_BASE/v${ver}/$tarball"
  info "better-sqlite3：下载官方 prebuild（electron ABI v$abi）..."
  if curl -L --fail --retry 2 -o "$build_dir/$tarball" "${GH_DL_PROXY}${url}"; then
    tar -xzf "$build_dir/$tarball" -C "$build_dir"
    dst=$(find "$build_dir" -name better_sqlite3.node | head -1)
    if [[ -n "$dst" ]]; then
      mkdir -p "$app_res/node_modules/better-sqlite3/build/Release" \
               "$app_res/node_modules/better-sqlite3/bin/linux-arm64-$abi"
      cp "$dst" "$app_res/node_modules/better-sqlite3/build/Release/better_sqlite3.node"
      cp "$dst" "$app_res/node_modules/better-sqlite3/bin/linux-arm64-$abi/better-sqlite3.node"
      rm -rf "$app_res/node_modules/better-sqlite3/bin/"darwin-*
      is_elf "$app_res/node_modules/better-sqlite3/build/Release/better_sqlite3.node" \
        && info "better-sqlite3：已回填（build/Release + bin/linux-arm64-$abi）✓" \
        || warn "better-sqlite3 回填后非 ELF"
    else
      warn "better-sqlite3 prebuild 包内未找到 better_sqlite3.node"
    fi
  else
    warn "better-sqlite3 prebuild 下载失败（可用 WORKBUDDY_GH_PROXY 设镜像前缀重试）"
  fi
}

write_stub_module() {
  local dest="$1" name="$2"
  mkdir -p "$dest"
  cat >"$dest/package.json" <<EOF
{
  "name": "$name",
  "version": "0.0.0",
  "main": "index.js",
  "private": true
}
EOF
  cat >"$dest/index.js" <<'EOF'
"use strict";
// Linux 移植 stub：导出全吞咽 Proxy 使遥测功能静默降级（应用已有守卫，此处仅兜底）。
const stub = new Proxy(function stub() { return stub; }, {
  apply: () => stub,
  construct: () => stub,
  get: (target, key) => {
    if (key === Symbol.toPrimitive) return () => "";
    if (key === "then") return undefined;
    return stub;
  },
});
module.exports = stub;
EOF
  info "已生成 stub：$name"
}

apply_stub_telemetry() {
  local app_res="$APP_DIR/resources/app"
  rm -rf "$app_res/node_modules/@tencent/qimei-node"
  write_stub_module "$app_res/node_modules/@tencent/qimei-node" "@tencent/qimei-node"
}

# ---------- 阶段 6：启动器 ----------
generate_launcher() {
  cat >"$APP_DIR/start.sh" <<'LAUNCHER'
#!/bin/bash
set -Eeuo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ID="workbuddy"

# [移植修复] 让内置资源解析器(resolveWorkbuddySidecarBundledAsset)能在扁平布局下找到
# cli/product.json 等关键配置。否则 configureElectronApp() 会抛
# "Failed to locate cli/product.json"，被外层 catch 误报为
# "安装文件损坏 / 请从 copilot.tencent.com/work/ 下载官方版"。
export WORKBUDDY_APP_PATH="$APP_DIR/resources/app"
export WORKBUDDY_RESOURCES_PATH="$APP_DIR/resources"
# 镜像 electron-builder 原生 Resources/app.asar.unpacked 结构（扁平化后该层被合并进
# resources/app，但解析器仍按 app.asar.unpacked 拼路径），用软链补回。
mkdir -p "$APP_DIR/resources"
if [ ! -e "$APP_DIR/resources/app.asar.unpacked" ]; then
  ln -sfn "$APP_DIR/resources/app" "$APP_DIR/resources/app.asar.unpacked"
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$APP_ID"
export CHROME_DESKTOP="${CHROME_DESKTOP:-${APP_ID}.desktop}"

if [[ "${1:-}" == "--diagnose" ]]; then
  failed=0
  for f in "$APP_DIR/electron" "$APP_DIR/resources/app/main/index.js" \
           "$APP_DIR/resources/app/package.json"; do
    if [[ -e "$f" ]]; then printf 'ok: %s\n' "$f"; else printf 'missing: %s\n' "$f"; failed=1; fi
  done
  for f in "$APP_DIR/resources/app/node_modules/koffi/build/koffi/linux_arm64/koffi.node" \
           "$APP_DIR/resources/app/cli/vendor/ripgrep/arm64-linux/ripgrep.node" \
           "$APP_DIR/resources/app/node_modules/node-pty/prebuilds/linux-arm64/pty.node" \
           "$APP_DIR/resources/app/node_modules/better-sqlite3/build/Release/better_sqlite3.node"; do
    if [[ ! -e "$f" ]]; then
      printf 'missing: %s\n' "$f"
    elif head -c4 "$f" 2>/dev/null | od -An -tx1 | grep -q '7f 45 4c 46'; then
      printf 'ok(ELF): %s\n' "$f"
    else
      printf 'NOT-ELF: %s\n' "$f"; failed=1
    fi
  done
  exit "$failed"
fi

mkdir -p "$STATE_DIR" 2>/dev/null || true
FLAGS_FILE="$APP_DIR/electron-flags.conf"
EXTRA_FLAGS=()
if [[ -r "$FLAGS_FILE" ]]; then
  mapfile -t EXTRA_FLAGS < <(grep -v '^[[:space:]]*#' "$FLAGS_FILE" || true)
fi

# chroot/proot 环境通常无 user namespaces，默认关沙箱；Wayland 可在 flags 文件加
# --ozone-platform=wayland 切换。
exec "$APP_DIR/electron" --no-sandbox "${EXTRA_FLAGS[@]}" "$@"
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
StartupWMClass=WorkBuddy
EOF
  info "启动器：$APP_DIR/start.sh（--diagnose 自检可用）"
}

configure_root_runtime() {
  mkdir -p "$DATA_DIR"
  local line
  local config_lines=(
    "export WORKBUDDY_DATA_DIR=$DATA_DIR"
    "alias workbuddy=\"$APP_DIR/start.sh\""
    "alias workbuddy-data=\"$APP_DIR/start.sh --user-data-dir $DATA_DIR\""
  )
  for line in "${config_lines[@]}"; do
    grep -Fqx "$line" "$TOOLSRC" 2>/dev/null || printf "%s\n" "$line" >>"$TOOLSRC"
  done
  info "已写入用户配置：$TOOLSRC（终端直接运行 workbuddy 启动）"
}

# ---------- 卸载 ----------
uninstall_workbuddy() {
  local -a targets=("$install_dir" "${XDG_CACHE_HOME:-$HOME/.cache}/workbuddy-desktop")
  local answer t
  if ((assume_yes == 0)); then
    printf '将删除以下目录：\n'
    printf '  - %s\n  - %s\n' "${targets[0]}" "${targets[1]}"
    if ((purge_data == 1)); then
      printf '同时删除运行数据：\n  - %s\n  - %s\n' "$DATA_DIR" "${XDG_CONFIG_HOME:-$HOME/.config}/WorkBuddy"
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
    for t in "$DATA_DIR" "${XDG_CONFIG_HOME:-$HOME/.config}/WorkBuddy"; do
      if [[ -e "$t" ]]; then
        info "删除运行数据：$t"
        rm -rf -- "$t"
      fi
    done
  fi
  if [[ -f "$TOOLSRC" ]]; then
    sed -i -e '/^export WORKBUDDY_DATA_DIR=/d' -e '/^alias workbuddy=/d' -e '/^alias workbuddy-data=/d' "$TOOLSRC"
  fi
  rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/$APP_ID.desktop"
  info '卸载完成；/sdcard/Download 下的 DMG/Electron 包均已保留'
}

# ---------- 参数解析 ----------
while (($#)); do
  case "$1" in
    --dir) (($# >= 2)) || die "--dir 需要一个目录"; install_dir=$2; shift 2 ;;
    --dmg) (($# >= 2)) || die "--dmg 需要一个文件路径"; dmg_path=$2; shift 2 ;;
    --electron-zip) (($# >= 2)) || die "--electron-zip 需要一个文件路径"; electron_zip_source=$2; shift 2 ;;
    --no-native) no_native=1; shift ;;
    --stub-telemetry) stub_telemetry=1; shift ;;
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
  uninstall_workbuddy
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
  dmg_path=$(find_downloaded_file "WorkBuddy*.dmg")
  if [[ -z "$dmg_path" ]]; then
    dmg_path=$(find_downloaded_file "*.dmg")
  fi
fi
if [[ -z "$dmg_path" ]]; then
  die "未找到 DMG；请用 --dmg 指定 WorkBuddy-darwin-arm64-*.dmg 路径"
fi
[[ -f "$dmg_path" ]] || die "找不到 DMG：$dmg_path"
dmg_path=$(realpath "$dmg_path")
info "使用 DMG：$dmg_path"

if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  info "目标环境：${PRETTY_NAME:-Linux}（$(uname -m)）"
fi

if ((dry_run == 1)); then
  stub_plan="跳过（qimei 依赖应用守卫自动降级）"
  if ((stub_telemetry == 1)); then stub_plan="替换 @tencent/qimei-node 为 Proxy stub"; fi
  cat <<EOF
预览（--dry-run）：
  1. 解包 DMG            $dmg_path
  2. 探测 Electron       自动（可 WORKBUDDY_ELECTRON_VERSION 覆盖）
  3. stock 运行时        精确匹配 electron-v${ELECTRON_VERSION:-<探测版>}-linux-arm64.zip（本地/下载/缓存）
  4. asar 解包           $APP_DIR/resources/app（平铺，等价 asar:false）
  5. 原生模块回填        koffi/rg 零动作 + node-pty npm 变体 + better-sqlite3 GitHub prebuild
  5.5 遥测处理           $stub_plan
  6. 启动器              $APP_DIR/start.sh + alias workbuddy
EOF
  exit 0
fi

# ---------- 主流程 ----------
mkdir -p "$WORK_DIR"
app_bundle=$(extract_dmg "$dmg_path")
detect_electron_version "$app_bundle"
prepare_runtime
assemble_app "$app_bundle"
if ((no_native == 1)); then
  warn "--no-native：跳过原生模块回填（darwin .node 加载将失败，仅用于主进程冒烟验证）"
else
  backfill_native_modules
fi
if ((stub_telemetry == 1)); then
  apply_stub_telemetry
fi
generate_launcher
configure_root_runtime

info "移植完成。验证顺序："
printf '  1) %s/start.sh --diagnose\n' "$APP_DIR"
printf '  2) workbuddy（或 %s/start.sh）\n' "$APP_DIR"
printf '  3) 观察登录页 → 打开工作区 → 触发终端/搜索/会话历史（覆盖 node-pty、rg、better-sqlite3）\n'
