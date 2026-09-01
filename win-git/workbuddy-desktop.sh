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
#     - better-sqlite3 12.8.0：npm install better-sqlite3@ver --runtime=electron
#       --target=<electron 版本> 经 prebuild-install 直接拉官方 electron ABI 预编译
#       （命中失败自动 node-gyp 源码编译），放 build/Release 与 bin/linux-arm64-<abi>/
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
# 脚本自身绝对路径（供 --update 在 app 运行时把完整构建派发到暂存目录）
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/$(basename "${BASH_SOURCE[0]}")"
DATA_DIR="${WORKBUDDY_DATA_DIR:-${TOOLS_HOME}/workbuddy-desktop-data}"
readonly DOWNLOAD_DIR="/sdcard/Download"
readonly ELECTRON_MIRROR="${ELECTRON_MIRROR:-https://npmmirror.com/mirrors/electron/}"
# better-sqlite3 走 npm + prebuild-install 直接拉 electron 预编译；本变量仅作为 npm 代理前缀
# （gitee/ghproxy 等镜像可覆盖），透传给 npm --proxy/--https-proxy，避免直连 GitHub 受限。
readonly GH_DL_PROXY="${WORKBUDDY_GH_PROXY:-}"
# electron 的 NODE_MODULE_VERSION（ABI），prepare_runtime 从实际 electron 二进制推导，
# 供 better-sqlite3 等 ABI 敏感原生模块选择 prebuild。版本无关（不依赖 mac 包内 darwin 目录布局）。
ELECTRON_ABI=""
# 自动更新：官方更新 feed（与 WorkBuddy 桌面端 autoUpdater 同源，公开无需鉴权）
readonly FETCH_UPDATE_BASE="${WORKBUDDY_UPDATE_URL:-https://copilot.tencent.com}"
readonly UPDATE_DOWNLOAD_DIR="${WORKBUDDY_UPDATE_CACHE:-/tmp/workbuddy-update}"

dmg_path="${WORKBUDDY_DMG_PATH:-}"
electron_zip_source="${WORKBUDDY_ELECTRON_ZIP_SOURCE:-}"
stub_telemetry=0
dry_run=0
no_native=0
update=0
uninstall=0
purge_data=0
assume_yes=0

usage() {
  cat <<'EOF'
用法：workbuddy-desktop.sh [选项]

把 WorkBuddy-darwin-arm64.dmg（stock Electron 37.10.3 + electron-builder）
移植为可在本机 Linux arm64 运行的自包含应用目录。原生模块全部来自官方
预编译二进制：node-pty 取 npm 变体包、better-sqlite3 经 npm + prebuild-install
直接拉 electron 运行时预编译（命中失败自动源码编译），无需手工拼 URL。

选项：
  --dir DIR          安装目录（默认：$TOOLS_HOME/workbuddy-desktop）
  --dmg FILE         指定 DMG（默认扫描 /sdcard/Download/WorkBuddy*.dmg）
  --electron-zip F   指定 electron-v*-linux-arm64.zip（默认自动扫描/下载）
  --no-native        跳过原生模块回填（仅验证主进程是否可启动）
  --stub-telemetry   把 @tencent/qimei-node 替换为 Proxy stub（遥测降级）
  --uninstall        删除安装目录、构建缓存；--purge-data 一并删运行数据
  --yes              卸载时不询问
  --update           检查线上最新版本（mac darwin-arm64），有新版本则下载并安装；
                     app 正在运行时改为完整构建到暂存目录，重启时自动应用
  --dry-run          只打印将执行的阶段
  -h, --help         显示帮助

环境变量：
  WORKBUDDY_DMG_PATH / WORKBUDDY_ELECTRON_ZIP_SOURCE / WORKBUDDY_INSTALL_DIR
  WORKBUDDY_DATA_DIR / WORKBUDDY_ELECTRON_VERSION（覆盖自动探测的 Electron 版本）
  WORKBUDDY_GH_PROXY（better-sqlite3 经 npm 拉预编译时的代理前缀，透传 npm --proxy/--https-proxy）
  WORKBUDDY_ALLOW_ELECTRON_MISMATCH=1（强制使用版本不匹配的本地 Electron zip）
  WORKBUDDY_UPDATE_URL（覆盖更新 feed 基址，默认 https://copilot.tencent.com）
  WORKBUDDY_UPDATE_CACHE（更新包下载缓存目录，默认 /tmp/workbuddy-update）
  多版本兼容：better-sqlite3 的 ABI 从实际 electron 二进制推导（不再依赖 mac 包内
  bin/darwin-* 目录，5.4.x 已无此目录），任意 WorkBuddy 版本均可正确回填原生模块。
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
  # 推导 electron 的 NODE_MODULE_VERSION（ABI），用于 better-sqlite3 等 ABI 敏感原生模块的 prebuild 选择。
  # 直接从实际 electron 二进制读取（ELECTRON_RUN_AS_NODE），版本无关，且不受 mac 包内目录布局变化影响
  # （5.4.x 起 better-sqlite3 改为 app.asar.unpacked 且不再带 bin/darwin-*，旧探测方式会拿到空 ABI）。
  if [[ -x "$APP_DIR/electron" ]]; then
    ELECTRON_ABI=$(NODE_OPTIONS= ELECTRON_RUN_AS_NODE=1 "$APP_DIR/electron" -p 'process.versions.modules' 2>/dev/null || true)
    [[ -n "$ELECTRON_ABI" ]] && info "Electron ABI (NODE_MODULE_VERSION)：$ELECTRON_ABI"
  fi
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
patch_safe_delete_shim() {
  # safe-delete 的 bash 兜底（trash_linux）在 linux 上即为预期实现；官方不为 linux 随包提供
  # genie-trash 二进制，trash_one() 探测到 TRASH_BIN 不可执行时会打一行误导性的
  # "genie-trash unavailable" 错误日志，让人误以为删除保护失效。本 patch 让 linux 上该探测
  # 失败静默降级（macOS/Windows 本应有二进制却缺失时仍告警）。
  local shim="$APP_DIR/resources/app/cli/vendor/shim/safe-bin/safe-delete-common.sh"
  [[ -f "$shim" ]] || { warn "safe-delete shim 不存在，跳过 patch"; return 0; }
  python3 - "$shim" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '''    else
        _safe_delete_diag "genie-trash unavailable: bin-not-executable path=$TRASH_BIN"
    fi
    # ---- 降级：当前平台实现 ----'''
new = '''    else
        # linux 平台官方不随包提供 genie-trash 二进制，内置 trash_linux 即为预期实现，
        # 视为正常降级，不打错误日志（避免误导“删除保护失效”）。
        if [ "$OS" != "Linux" ]; then
            _safe_delete_diag "genie-trash unavailable: bin-not-executable path=$TRASH_BIN"
        fi
    fi
    # ---- 降级：当前平台实现 ----'''
if old in s:
    open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
    print("patched")
else:
    print("SKIP: pattern not found (already patched or upstream changed)")
PY
  info "safe-delete shim：linux 静默降级 patch 已应用 ✓"
}

apply_runtime_patches() {
  # 对已【安装】的 app 应用所有运行时修复，无需重跑完整构建（extract_dmg 等）。
  # 重建流程（main）也会在 backfill 之后调用本函数，保证解包态与安装态一致。
  local app_dir="${APP_DIR:-/root/tools/workbuddy-desktop/app}"
  local app_res="$app_dir/resources/app"
  [[ -d "$app_res" ]] || die "找不到已安装 app：$app_res（patch 子命令需指向已安装目录，或用 APP_DIR=/path 指定）"
  info "对已安装 app 应用运行时 patch：$app_dir"

  # 1) ripgrep 执行位 + 0 字节占位清理（Grep/Glob 工具的执行体）
  local rg_dst="$app_res/cli/vendor/ripgrep/arm64-linux/rg"
  if [[ -e "$rg_dst" ]]; then
    chmod 755 "$rg_dst"
    info "ripgrep：arm64-linux/rg 已置 755 ✓"
  elif command -v rg >/dev/null 2>&1; then
    info "ripgrep：arm64-linux/rg 缺失，将回落 PATH 上的 rg（系统已安装）"
  else
    warn "ripgrep：arm64-linux/rg 缺失且系统无 rg，Grep/Glob 工具将不可用"
  fi
  local rg_node="$app_res/cli/vendor/ripgrep/arm64-linux/ripgrep.node"
  if [[ -f "$rg_node" && ! -s "$rg_node" ]]; then
    rm -f "$rg_node"
    info "ripgrep：已清理 0 字节 ripgrep.node 占位（避免 --diagnose 误报）"
  fi

  # 2) safe-delete 静默降级（linux 不随包提供 genie-trash，trash_linux 即为预期实现）
  patch_safe_delete_shim

  # 3) 重新生成启动器（含正确的 --diagnose 自检），并置可执行
  generate_launcher
  chmod +x "$app_dir/start.sh"
  info "start.sh 已重新生成（--diagnose 自检可用）"

  # 4) 更新器 patch：Linux 下 checkForUpdates 委托给移植脚本（自带更新检查即走脚本）
  patch_app_updater

  info "运行时 patch 完成 ✓（无需重跑完整构建）"
}

# 更新器 patch：把内置 UpdateServiceLinux.checkForUpdates 委托给移植脚本
# workbuddy-desktop.sh（脚本统一负责查 macOS darwin feed、下载、原生模块回填、
# 生成 .update-stage + pending，重启由 start.sh 原子切换）。否则 Linux 下更新器
# 请求 workbuddy-linux-arm64 平台资源，服务端无此通道，检查更新必失败。
# 幂等：main/index.js 已含 _portCheckForUpdates 则跳过。
patch_app_updater() {
  local main_js="$APP_DIR/resources/app/main/index.js"
  [[ -f "$main_js" ]] || { warn "main/index.js 不存在，跳过 updater patch"; return 0; }
  [[ -w "$main_js" ]] || { warn "main/index.js 不可写，跳过 updater patch"; return 0; }
  info "patch 更新器：Linux 下 checkForUpdates 委托给移植脚本 workbuddy-desktop.sh"
python3 - "$main_js" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
if '_portCheckForUpdates' in s:
    print('skip: already patched'); sys.exit(0)
marker = 'var UpdateServiceLinux = class extends AbstractUpdateService {'
if marker not in s:
    print('skip: UpdateServiceLinux not found'); sys.exit(0)
i = s.index(marker)
decl = 'async checkForUpdates(explicit = false) {'
j = s.index(decl, i)
s = s[:j] + 'async checkForUpdates(explicit = false) { return this._portCheckForUpdates(explicit);' + s[j+len(decl):]
m = re.search(r'quitAndInstall\(\)\s*\{[^}]*\}', s[i:])
if not m:
    print('error: quitAndInstall not found'); sys.exit(1)
end = i + m.end()
methods = r'''_portCheckForUpdates(explicit) {
this.setLastExplicit(explicit);
if (this._portBusy) return;
this._portBusy = true;
try {
this.setState("checking");
const cp = require("child_process");
const script = this._resolvePortUpdateScript();
if (!script) {
this.logger?.warn("[UpdateService.linux] no port update script (workbuddy-desktop.sh) found; skip");
this.fileLogger.warn("[linux] no port update script found");
this.setState("idle");
return;
}
this.logger?.info("[UpdateService.linux] delegating update to port script: " + script);
const child = cp.spawn("bash", [script, "--update", "--yes"], { stdio: ["ignore", "pipe", "pipe"] });
let out = "";
child.stdout.on("data", (d) => { out += d.toString(); });
child.stderr.on("data", (d) => { out += d.toString(); });
child.on("error", (e) => {
this._portBusy = false;
this.logger?.error("[UpdateService.linux] spawn port script failed: " + (e && e.message));
this.setState("idle");
});
child.on("close", (code) => {
this._portBusy = false;
this.fileLogger.info("[linux] port script exited code=" + code);
if (/已暂存|已立即安装/.test(out)) {
const m = out.match(/(\d+\.\d+\.\d+(?:\.\d+)?)/);
const ver = m ? m[1] : this.version;
this.activeUpdateVersion = ver;
this.setState("available", { version: ver, releaseDate: "", releaseNotes: "已通过移植脚本下载并暂存，请重启 WorkBuddy 完成升级", downloadUrl: script });
this.logger?.info("[UpdateService.linux] staged update " + ver + "; restart to apply");
} else if (/已是最新|无需更新|是最新/.test(out)) {
this.setState("idle");
} else {
this.setState("error", void 0, void 0, { message: "port update script failed (code " + code + ")", code: "PORT_UPDATE_FAILED" });
this.logger?.error("[UpdateService.linux] port script output: " + out.slice(-3000));
}
});
} catch (err) {
this._portBusy = false;
this.logger?.error("[UpdateService.linux] _portCheckForUpdates error: " + (err && err.message));
this.setState("idle");
}
}
_resolvePortUpdateScript() {
const cands = [
process.env.WORKBUDDY_DESKTOP_SH,
"/root/sh/win-git/workbuddy-desktop.sh",
"/root/tools/workbuddy-desktop/workbuddy-desktop.sh",
require("node:path").join(require("node:path").dirname(process.resourcesPath), "..", "workbuddy-desktop.sh")
].filter(Boolean);
for (const c of cands) {
try { if (require("node:fs").existsSync(c) && require("node:fs").statSync(c).isFile()) return c; } catch (e) {}
}
return null;
}'''
s = s[:end] + methods + s[end:]
open(p, 'w', encoding='utf-8').write(s)
print('patched: UpdateServiceLinux.checkForUpdates -> port script delegate')
PY
}

# ---------- 自动更新：查版本 / 下载 / 安装 ----------
# 官方更新通道 copilot.tencent.com/v2/update 返回最新 macOS arm64 安装包（zip）直链与四段版本号，
# 与 WorkBuddy 桌面端 autoUpdater 同源（main/index.js buildUpdateFeedUrl），公开、无需鉴权。

# 四段语义化版本比较：version_gt A B → A 是否严格大于 B（按 . 分段数值比较，段数不足补 0）
version_gt() {
  python3 - "$1" "$2" <<'PY'
import sys
def norm(v):
    out = []
    for p in str(v).split('.'):
        try: out.append(int(p))
        except ValueError: out.append(0)
    return out
a, b = norm(sys.argv[1]), norm(sys.argv[2])
while len(a) < len(b): a.append(0)
while len(b) < len(a): b.append(0)
print('1' if a > b else '0')
PY
}

# 读已安装完整版本：优先标记文件，回退 package.json version
get_installed_version() {
  local f="$install_dir/.workbuddy-version" v=""
  if [[ -f "$f" ]]; then v=$(head -1 "$f" 2>/dev/null | tr -d '[:space:]'); fi
  if [[ -z "$v" ]]; then
    local pj="$APP_DIR/resources/app/package.json"
    [[ -f "$pj" ]] && v=$(python3 -c "import json;print(json.load(open('$pj')).get('version',''))" 2>/dev/null)
  fi
  printf '%s' "$v"
}

# 记录已安装完整版本到标记文件（feed 返回四段版本，避免下次误判）
write_installed_version() {
  [[ -n "$1" ]] || return 0
  printf '%s\n' "$1" > "$install_dir/.workbuddy-version"
  info "已记录安装版本：$1 → $install_dir/.workbuddy-version"
}

# 从解包出的 .app 读完整版本（CFBundleVersion，失败回退 package.json）
read_app_full_version() {
  local app_dir="$1" v=""
  local plist="$app_dir/Contents/Info.plist"
  if [[ -f "$plist" ]]; then
    v=$(python3 - "$plist" <<'PY' 2>/dev/null || true
import plistlib, sys
try:
    pl = plistlib.load(open(sys.argv[1], 'rb'))
    print(pl.get('CFBundleVersion') or pl.get('CFBundleShortVersionString') or '')
except Exception:
    pass
PY
)
  fi
  if [[ -z "$v" ]]; then
    v=$(python3 -c "import json;print(json.load(open('$app_dir/Contents/Resources/app/package.json')).get('version',''))" 2>/dev/null || true)
  fi
  printf '%s' "$v"
}

# 查更新 feed：必须传真实本地版本才会返回比它新的版本；version=0.0.0 返回稳定版（可能偏旧），
# 已是最新时服务端返回 HTTP 204（无 version/url 字段）。故 get_installed_version 优先读标记/package.json。
fetch_latest_feed() {
  local local_v="${1:-0.0.0}" url
  url="${FETCH_UPDATE_BASE%/}/v2/update?platform=workbuddy-darwin-arm64&version=${local_v}"
  curl -sS -m 20 -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) WorkBuddy" "$url" 2>/dev/null || true
}

# 解包安装包：.dmg → 7z；.zip → unzip。返回 .app 目录路径
extract_app_bundle() {
  local pkg="$1"
  case "$pkg" in
    *.zip) extract_zip "$pkg" ;;
    *.dmg) extract_dmg "$pkg" ;;
    *) die "不支持的包格式：$pkg（仅支持 .dmg / .zip）" ;;
  esac
}
extract_zip() {
  local zip="$1" extract_dir="$WORK_DIR/zip-extract" status=0 app_dir
  command -v unzip >/dev/null 2>&1 || die "缺少 unzip，请先安装。"
  rm -rf "$extract_dir"; mkdir -p "$extract_dir"
  info "解压 ZIP 安装包：$zip"
  unzip -q -o "$zip" -d "$extract_dir" || status=$?
  app_dir=$(find "$extract_dir" -maxdepth 4 -name "WorkBuddy.app" -type d | head -1)
  [[ -n "$app_dir" ]] || app_dir=$(find "$extract_dir" -maxdepth 4 -name "*.app" -type d | head -1)
  [[ -n "$app_dir" ]] || die "ZIP 内未找到 .app 包"
  info "找到应用包：$(basename "$app_dir")"
  printf '%s' "$app_dir"
}

# 通用安装流程（--dmg 手动安装与 --update 自动更新共用）
do_install() {
  local pkg="$1" override_v="${2:-}" app_bundle
  mkdir -p "$WORK_DIR"
  app_bundle=$(extract_app_bundle "$pkg")
  detect_electron_version "$app_bundle"
  prepare_runtime
  assemble_app "$app_bundle"
  if ((no_native == 1)); then
    warn "--no-native：跳过原生模块回填（darwin .node 加载将失败，仅用于主进程冒烟验证）"
  else
    backfill_native_modules
  fi
  apply_runtime_patches
  if ((stub_telemetry == 1)); then apply_stub_telemetry; fi
  generate_launcher
  configure_root_runtime
  if [[ -n "$override_v" ]]; then
    write_installed_version "$override_v"
  else
    write_installed_version "$(read_app_full_version "$app_bundle")"
  fi
  info "安装完成。验证顺序："
  printf '  1) %s/start.sh --diagnose\n' "$APP_DIR"
  printf '  2) workbuddy（或 %s/start.sh）\n' "$APP_DIR"
  printf '  3) 观察登录页 → 打开工作区 → 触发终端/搜索/会话历史（覆盖 node-pty、rg、better-sqlite3）\n'
}

# 自动更新：查 feed（传真实本地版本）→ 下载 mac 包 → 安装 / 暂存
# feed 实测行为：version=本地版本 返回比它新的版本；version=0.0.0 返回稳定版（偏旧）；
# 已是最新返回 HTTP 204（无 version/url 字段）。故必须传真实本地版本。
# 运行时策略：app 正在运行 → 完整构建到暂存目录并写 pending 标记，重启时由 start.sh 原子切换；
#            app 未运行 → 直接 do_install，并继续循环收敛到最新（应对多次中间版本）。
cmd_update() {
  local local_v feed latest_v url zip iter=0
  local_v=$(get_installed_version)
  info "已安装版本：${local_v:-未知（将按 0.0.0 查询，可能仅得稳定版）}"
  info "查询更新服务器：$FETCH_UPDATE_BASE（platform=workbuddy-darwin-arm64，即 macOS 官方包）"

  while ((iter < 20)); do
    iter=$((iter + 1))
    feed=$(fetch_latest_feed "$local_v")
    latest_v=$(printf '%s' "$feed" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin); print(d.get('productVersion') or d.get('version') or '')
except Exception: pass" 2>/dev/null)
    url=$(printf '%s' "$feed" | python3 -c "import sys,json
try:
    d=json.load(sys.stdin); print(d.get('url') or '')
except Exception: pass" 2>/dev/null)
    if [[ -z "$latest_v" || -z "$url" ]]; then
      info "已是最新版本（${local_v:-?}），无需更新。"
      break
    fi
    if [[ -n "$local_v" ]] && [[ "$(version_gt "$latest_v" "$local_v")" != "1" ]]; then
      info "已是最新版本（${local_v} >= ${latest_v}），无需更新。"
      break
    fi
    info "发现新版本：${local_v:-?} → $latest_v"

    if ((dry_run == 1)); then
      info "（dry-run）将下载 $url 并安装到 $APP_DIR"
      break
    fi
    if ((assume_yes != 1)); then
      local ans
      read -r -p "确认下载并更新到 $latest_v? [Y/n] " ans
      case "$ans" in n|N) info "已取消。"; return 0 ;; esac
    fi

    mkdir -p "$UPDATE_DOWNLOAD_DIR"
    zip="$UPDATE_DOWNLOAD_DIR/WorkBuddy-darwin-arm64-${latest_v}.zip"
    if [[ ! -s "$zip" ]]; then
      info "下载新包：$url"
      curl -L --fail --continue-at - --progress-bar -o "$zip" "$url" || die "下载失败：$url"
    else
      info "复用已下载缓存：$zip"
    fi

    # 避免覆盖正在运行的 app：完整构建到暂存目录，重启时由 start.sh 原子切换
    if pgrep -f "$APP_DIR/electron" >/dev/null 2>&1; then
      local stage_dir="$install_dir/.update-stage"
      info "WorkBuddy 正在运行 → 构建到暂存目录 $stage_dir（重启时自动应用）"
      rm -rf "$stage_dir"
      NODE_OPTIONS= bash "$SELF" --dmg "$zip" --dir "$stage_dir" \
        || { warn "暂存构建失败，已保留下载包 $zip；可退出 WorkBuddy 后手动运行：bash $SELF --update"; return 1; }
      # 暂存构建的 .workbuddy-version 由 read_app_full_version 写（三段 CFBundleVersion），
      # 但更新语义用 feed 的四段版本号；此处直接落完整版本，供重启切换后 start.sh 透写到真实目录。
      printf '%s\n' "$latest_v" > "$stage_dir/.workbuddy-version"
      # 安全闸：暂存构建须 --diagnose 全绿（尤其 better-sqlite3 须为 ELF），否则不写 pending，
      # 避免自动应用"原生模块缺失"的坏包（如某版本 better-sqlite3 回填失败）。
      if ! NODE_OPTIONS= bash "$stage_dir/app/start.sh" --diagnose >/dev/null 2>&1; then
        warn "暂存构建 --diagnose 未通过（原生模块缺失，例如 better-sqlite3），中止自动暂存；已保留下载包 $zip 供手动处理"
        rm -rf "$stage_dir"
        return 1
      fi
      printf '%s:%s\n' "$stage_dir/app" "$latest_v" > "$install_dir/.workbuddy-pending-update"
      info "已暂存 $latest_v；下次重启 WorkBuddy 时自动应用（或退出后手动 bash $SELF --update 立即生效）。"
      break
    else
      do_install "$zip" "$latest_v"
      local_v="$latest_v"
      # 继续循环：若还有更新的中间版本，一次性收敛到最新
    fi
  done
  return 0
}

backfill_native_modules() {
  local app_res="$APP_DIR/resources/app" build_dir="$WORK_DIR/native-build"
  local pkg_json ver abi tarball url dst

  # 1. koffi / ripgrep：包内自带 linux_arm64 ELF，仅校验
  if is_elf "$app_res/node_modules/koffi/build/koffi/linux_arm64/koffi.node"; then
    info "koffi：包内自带 linux_arm64 ELF ✓（win32 WM_COPYDATA 分支外不参与启动）"
  else
    warn "koffi linux_arm64 缺失或非 ELF（主进程有 win32 守卫，理论上不影响）"
  fi
  # ripgrep（Grep/Glob 工具的执行体）：CLI 侧 RipGrepUtils.getBuiltinRipgrepConfig() 硬编码
  #   resolve(vendor/ripgrep, `${arch()}-${platform()}`, "rg") 并用 spawn 起子进程，
  #   全程不加载 ripgrep.node（见 cli/dist/codebuddy.js）。所以判定对象必须是 rg 而非 .node。
  # 而 isBuiltinRipgrepAvailable() 只做 fileExists()，不查 X_OK、不比对大小：该路径一旦存在，
  #   ensureRgConfig() 就不会回落系统 rg。因此它必须是「可执行的真 ELF」，否则 Grep 工具直接抛
  #   Failed to run ripgrep: spawn .../arm64-linux/rg EACCES（占位空文件则为 ENOEXEC）。
  # 两个叠加的坑：
  #   ① asar 容错解包会给被 electron-builder 裁掉的其他平台 unpacked 文件建 0 字节占位，
  #      fs.writeFileSync 默认 mode 0666&~umask → 644，arm64-linux/rg 正在其中；
  #   ② cp 覆盖【已存在】文件时只写内容、不改目标 mode，故回填后 md5 与 /usr/bin/rg 一致
  #      但权限仍是 644 → 无执行位。必须显式 chmod，不能依赖 cp 传递权限。
  local rg_dst="$app_res/cli/vendor/ripgrep/arm64-linux/rg"
  local rg_node="$app_res/cli/vendor/ripgrep/arm64-linux/ripgrep.node"
  mkdir -p "$(dirname "$rg_dst")"
  if is_elf "$rg_dst"; then
    chmod 755 "$rg_dst"
    info "ripgrep：包内自带 arm64-linux/rg ELF ✓（已强制置 755）"
  elif is_elf /usr/bin/rg; then
    cp -f /usr/bin/rg "$rg_dst"
    chmod 755 "$rg_dst"
    info "ripgrep：arm64-linux/rg 已用系统 ripgrep 回填并置 755 ✓"
  else
    # 关键：留着 0 字节占位会让 isBuiltinRipgrepAvailable() 误判「内置可用」，
    # 堵死 ensureRgConfig() 的系统 rg 回落分支；删掉才能让 CLI 走 PATH 上的 rg。
    rm -f "$rg_dst"
    warn "ripgrep arm64-linux/rg 缺失且系统无 /usr/bin/rg，已删除占位以便 CLI 回落 PATH 上的 rg（apt install ripgrep 后重跑可内置回填）"
  fi
  # ripgrep.node 是 NAPI 变体，当前 CLI 不加载；0 字节占位留着只会让 --diagnose 误报，清掉
  if [[ -f "$rg_node" && ! -s "$rg_node" ]]; then
    rm -f "$rg_node"
  fi

  # 2. node-pty：取 @lydell linux-arm64 变体包（NAPI，ABI 无关）
  local pty_var_ver
  pty_var_ver=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('version',''))" \
    "$app_res/node_modules/@lydell/node-pty-darwin-arm64/package.json" 2>/dev/null || true)
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

  # 3. better-sqlite3：直接 npm install better-sqlite3@ver 拉 electron 运行时预编译。
  #    不再手工拼 GitHub tarball URL、也不再单独做「源码编译兜底开关」——npm 的 install 脚本本身
  #    就是 auto 链路：prebuild-install 下载 electron ABI 预编译（命中即落地）→ 失败自动 node-gyp 源码编译。
  #      - 版本从包内 better-sqlite3/package.json 读（与 mac 自带版本严格一致，零编造）；
  #      - ABI / 目标运行时由 --runtime=electron --target=$ELECTRON_VERSION 推导（版本无关，
  #        不依赖 mac 包内 bin/darwin-* 目录布局，5.4.x 起该目录已不存在也照样正确）；
  #      - 代理用 WORKBUDDY_GH_PROXY 透传 npm --proxy/--https-proxy；NODE_OPTIONS 清空以免 --use-system-ca 干扰。
  #    等价于 codex-desktop 用 npm 取原生变体包的思路，把「解包/回填」彻底交给 npm。
  local pkg_json="$app_res/node_modules/better-sqlite3/package.json"
  local ver=""
  [[ -f "$pkg_json" ]] && ver=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('version',''))" "$pkg_json" 2>/dev/null || true)
  if [[ -z "$ver" ]]; then
    warn "better-sqlite3 版本探测失败，跳过回填"
    return 0
  fi
  if [[ -z "${ELECTRON_VERSION:-}" ]]; then
    warn "缺少 ELECTRON_VERSION，无法定位 electron 预编译，跳过 better-sqlite3 回填"
    return 0
  fi
  local bs3_dir="$build_dir/bs3" dst=""
  rm -rf "$bs3_dir"
  mkdir -p "$bs3_dir"
  ( cd "$bs3_dir" && echo '{"name":"bs3-tmp","version":"1.0.0","private":true}' > package.json )
  local -a npm_proxy_args=()
  [[ -n "${GH_DL_PROXY:-}" ]] && npm_proxy_args+=(--proxy="${GH_DL_PROXY%/}" --https-proxy="${GH_DL_PROXY%/}")
  info "better-sqlite3：npm 拉预编译（v$ver / electron $ELECTRON_VERSION / ABI v${ELECTRON_ABI:-?}）..."
  if ( cd "$bs3_dir" && NODE_OPTIONS= npm install "better-sqlite3@$ver" \
        --runtime=electron --target="$ELECTRON_VERSION" \
        --dist-url=https://electronjs.org/headers \
        --platform=linux --arch=arm64 --no-save "${npm_proxy_args[@]}" >&2 ); then
    dst=$(find "$bs3_dir/node_modules/better-sqlite3" -name better_sqlite3.node 2>/dev/null | head -1)
  else
    warn "npm install better-sqlite3 失败（预编译下载与源码编译兜底均失败）"
  fi
  if [[ -n "$dst" && -f "$dst" ]]; then
    install_bs3_binary "$app_res" "$dst"
    is_elf "$app_res/node_modules/better-sqlite3/build/Release/better_sqlite3.node" \
      && info "better-sqlite3：已回填（build/Release + bin/linux-arm64-${ELECTRON_ABI}）✓" \
      || warn "better-sqlite3 回填后非 ELF"
  else
    warn "better-sqlite3 回填失败"
  fi
}

# 把 npm 拉到的 better_sqlite3.node 落到 app bundle 两处（electron 从 build/Release 加载，
# bin/linux-arm64-<abi> 为兼容位置），并清掉 mac 残留的 darwin-* 占位以便 --diagnose 干净。
install_bs3_binary() {
  local app_res="$1" src="$2"
  [[ -n "${ELECTRON_ABI:-}" ]] || ELECTRON_ABI=$(NODE_OPTIONS= ELECTRON_RUN_AS_NODE=1 \
    "$APP_DIR/electron" -p 'process.versions.modules' 2>/dev/null || true)
  mkdir -p "$app_res/node_modules/better-sqlite3/build/Release" \
           "$app_res/node_modules/better-sqlite3/bin/linux-arm64-${ELECTRON_ABI}"
  cp "$src" "$app_res/node_modules/better-sqlite3/build/Release/better_sqlite3.node"
  cp "$src" "$app_res/node_modules/better-sqlite3/bin/linux-arm64-${ELECTRON_ABI}/better-sqlite3.node"
  rm -rf "$app_res/node_modules/better-sqlite3/bin/"darwin-*
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
# 【必须是相对软链】否则 start.sh 的待定更新 atomic mv 切换（把 .update-stage/app 改名为
# app）后，绝对软链会指向已被删除的旧路径而悬空，解析器找不到 cli/product.json ->
# 运行时报"安装文件损坏 / 请从 copilot.tencent.com/work/ 下载官方版"。相对软链随目录移动始终有效。
# 每次启动都强制重建（幂等、开销可忽略），可自愈任何残留的绝对/悬空软链。
mkdir -p "$APP_DIR/resources"
ln -sfn app "$APP_DIR/resources/app.asar.unpacked"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$APP_ID"
export CHROME_DESKTOP="${CHROME_DESKTOP:-${APP_ID}.desktop}"

if [[ "${1:-}" == "--diagnose" ]]; then
  failed=0
  for f in "$APP_DIR/electron" "$APP_DIR/resources/app/main/index.js" \
           "$APP_DIR/resources/app/package.json"; do
    if [[ -e "$f" ]]; then printf 'ok: %s\n' "$f"; else printf 'missing: %s\n' "$f"; failed=1; fi
  done
  for f in "$APP_DIR/resources/app/node_modules/koffi/build/koffi/linux_arm64/koffi.node" \
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
  # ripgrep 单独校验：CLI 用的是 vendor/ripgrep/arm64-linux/rg（spawn 子进程），不是 ripgrep.node，
  # 且它只做 fileExists 判定 → 存在但不可执行时不会回落系统 rg，Grep 工具直接 spawn EACCES。
  RG_BIN="$APP_DIR/resources/app/cli/vendor/ripgrep/arm64-linux/rg"
  if [[ ! -e "$RG_BIN" ]]; then
    printf 'missing: %s（预期回落 PATH 上的 rg）\n' "$RG_BIN"
    if ! command -v rg >/dev/null 2>&1; then
      printf 'NO-FALLBACK: PATH 中也没有 rg，Grep/Glob 工具将不可用\n'; failed=1
    fi
  elif ! head -c4 "$RG_BIN" 2>/dev/null | od -An -tx1 | grep -q '7f 45 4c 46'; then
    printf 'NOT-ELF: %s（多为 asar 占位空文件，删掉即可回落系统 rg）\n' "$RG_BIN"; failed=1
  elif [[ ! -x "$RG_BIN" ]]; then
    printf 'NOT-EXEC: %s（chmod 755 修复，否则 Grep 报 spawn EACCES）\n' "$RG_BIN"; failed=1
  else
    printf 'ok(ELF,+x): %s\n' "$RG_BIN"
  fi
  # product.json：解析器实际经由 app.asar.unpacked/cli/product.json 定位（扁平化后由软链补回）。
  # 若 app.asar.unpacked 软链悬空/损坏，运行时才会报"安装文件损坏"，--diagnose 必须提前暴露，
  # 否则会出现"diagnose 全绿但启动即崩"的假绿。
  PRODUCT_JSON="$APP_DIR/resources/app.asar.unpacked/cli/product.json"
  if [[ ! -e "$PRODUCT_JSON" ]]; then
    printf 'missing: %s（app.asar.unpacked 软链悬空或 product.json 缺失 -> 运行时将报"安装文件损坏"）\n' "$PRODUCT_JSON"; failed=1
  elif head -c1 "$PRODUCT_JSON" 2>/dev/null | od -An -tx1 | grep -q '7b'; then
    printf 'ok(json): %s\n' "$PRODUCT_JSON"
  else
    printf 'NOT-JSON: %s（product.json 开头非 { ，可能截断/损坏）\n' "$PRODUCT_JSON"; failed=1
  fi
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

# [自动更新] 若此前在 WorkBuddy 运行期间下载了新包（--update 暂存），重启时原子切换到新版本。
# 暂存目录 .update-stage/app 已是完整 Linux 构建，这里只做本地 mv，无需联网，启动不卡顿。
PENDING_MARKER="$APP_DIR/../.workbuddy-pending-update"
if [[ -f "$PENDING_MARKER" ]]; then
  IFS=: read -r STAGE_APP STAGE_V < "$PENDING_MARKER" 2>/dev/null || true
  if [[ -n "$STAGE_APP" && -d "$STAGE_APP" ]] && ! pgrep -f "$APP_DIR/electron" >/dev/null 2>&1; then
    echo "[workbuddy] 应用待定更新 -> ${STAGE_V:-?}"
    BACKUP="$APP_DIR/../app.old"
    rm -rf "$BACKUP"
    mv "$APP_DIR" "$BACKUP"
    if mv "$STAGE_APP" "$APP_DIR" 2>/dev/null; then
      # 把完整版本号落到真实安装目录（.update-stage 即将被 rm -rf，其内标记会一并消失，
      # 否则下次更新会误判为旧版本而无限重下）。
      [[ -n "$STAGE_V" ]] && printf '%s\n' "$STAGE_V" > "$APP_DIR/../.workbuddy-version"
      # 切换后强制重建【相对】app.asar.unpacked 软链，覆盖暂存包里可能残留的绝对软链，
      # 否则解析器找不到 cli/product.json -> "安装文件损坏"。
      ln -sfn app "$APP_DIR/resources/app.asar.unpacked"
      rm -rf "$BACKUP" "$PENDING_MARKER" "${STAGE_APP%/*}"
      echo "[workbuddy] 更新完成：${STAGE_V:-?}（回滚备份在 app.old，确认无误可手动删除）"
    else
      echo "[workbuddy] 切换失败，回退到旧版本"
      mv "$BACKUP" "$APP_DIR" 2>/dev/null || true
      rm -f "$PENDING_MARKER"
    fi
  else
    echo "[workbuddy] 待定更新未应用（app 仍在运行或暂存缺失），跳过"
    rm -f "$PENDING_MARKER"
  fi
fi

exec "$APP_DIR/electron" --no-sandbox "${EXTRA_FLAGS[@]}" "$@"
LAUNCHER
  chmod +x "$APP_DIR/start.sh"

  # 默认生成 electron-flags.conf（仅当不存在时，避免覆盖用户自定义）。
  # 关闭硬件 GPU 加速、改用软件渲染，规避 nouveau / 闭源驱动异常导致的画面变形、撕裂、黑屏。
  local flags_file="$APP_DIR/electron-flags.conf"
  if [[ ! -e "$flags_file" ]]; then
    cat >"$flags_file" <<'FLAGS'
# WorkBuddy Linux 移植启动参数（由 workbuddy-desktop.sh 生成）
# 每行一个 electron flag；以 # 开头为注释。start.sh 会读取本文件并附加到启动命令。
# 修改后无需重跑移植脚本，直接重启 start.sh 即可生效。

# —— 关闭硬件 GPU 加速，改用软件渲染（llvmpipe / SwiftShader）——
# 适用：画面变形 / 撕裂 / 黑屏 / 崩溃，或 nouveau、闭源驱动异常。
--disable-gpu
--disable-gpu-compositing
--disable-accelerated-2d-canvas
--disable-gpu-rasterization
--enable-software-rasterizer

# —— 若关闭 GPU 后仍异常（多为 Wayland 缩放 / 混成问题）——
# 取消下一行注释，强制走 X11 而非 Wayland：
# --ozone-platform=x11
FLAGS
    info "已生成默认 $flags_file（已关闭 GPU 硬件加速）"
  fi

  # 桌面项仅真实安装时写入；暂存构建跳过，避免 .desktop 指向临时路径
  if [[ "$install_dir" != *.update-stage ]]; then
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
  fi
  info "启动器：$APP_DIR/start.sh（--diagnose 自检可用）"
}

configure_root_runtime() {
  # 暂存构建（install_dir 以 .update-stage 结尾）不污染用户环境：
  # 别名/rc/桌面项必须指向真实安装目录，否则更新时别名会被临时路径劫持。
  [[ "$install_dir" == *.update-stage ]] && return 0
  # 临时目录（/tmp、/sdcard/Download 等）视为测试/误装，不写用户环境，避免别名被劫持到即将删除的路径。
  case "$install_dir" in
    /tmp/*|/tmp|/sdcard/Download/*|/sdcard/Download) return 0 ;;
  esac
  mkdir -p "$DATA_DIR"
  # 幂等：先清掉旧的 workbuddy 相关行（避免临时/旧路径别名堆积），再写当前正确值
  local tmp; tmp=$(mktemp)
  grep -vE '^(export WORKBUDDY_DATA_DIR=|alias workbuddy=|alias workbuddy-data=)' "$TOOLSRC" 2>/dev/null > "$tmp" || true
  cat "$tmp" > "$TOOLSRC" 2>/dev/null || true
  rm -f "$tmp"
  {
    printf 'export WORKBUDDY_DATA_DIR=%s\n' "$DATA_DIR"
    printf 'alias workbuddy="%s/start.sh"\n' "$APP_DIR"
    printf 'alias workbuddy-data="%s/start.sh --user-data-dir %s"\n' "$APP_DIR" "$DATA_DIR"
  } >> "$TOOLSRC"
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
    --update) update=1; shift ;;
    --electron-zip) (($# >= 2)) || die "--electron-zip 需要一个文件路径"; electron_zip_source=$2; shift 2 ;;
    --no-native) no_native=1; shift ;;
    patch) patch_target="${2:-/root/tools/workbuddy-desktop/app}"; shift; APP_DIR="$patch_target" apply_runtime_patches; exit 0 ;;
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
if ((assume_yes != 0)) && ((uninstall == 0)) && ((update == 0)); then die '--yes 只能与 --uninstall 或 --update 一起使用'; fi

# ---------- 预检 ----------
for cmd in node npm python3 unzip curl; do
  command -v "$cmd" >/dev/null || die "缺少 $cmd，请先安装。"
done
# 清空 NODE_OPTIONS：某些环境注入 --use-system-ca 等会令 `node -e` 直接报错，
# 改用 `node --version` 解析大版本，保证自动化在任何环境都能跑（含 WorkBuddy automation）。
node_ver=$(NODE_OPTIONS= node --version 2>/dev/null || true)
node_major=$(printf '%s' "${node_ver#v}" | grep -oE '^[0-9]+' | head -1)
[[ -n "$node_major" && "$node_major" -ge 20 ]] || die "需要 Node.js >= 20（当前 ${node_ver:-未知}）"

if ((update == 1)); then
  cmd_update
  exit 0
fi

if [[ -z "$dmg_path" ]]; then
  dmg_path=$(find_downloaded_file "WorkBuddy*.dmg")
  if [[ -z "$dmg_path" ]]; then
    dmg_path=$(find_downloaded_file "*.dmg")
  fi
fi
if [[ -z "$dmg_path" ]]; then
  die "未找到 DMG；请用 --dmg 指定 WorkBuddy-darwin-arm64-*.dmg，或使用 --update 自动下载最新版"
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
  1. 解包安装包        $dmg_path
  2. 探测 Electron       自动（可 WORKBUDDY_ELECTRON_VERSION 覆盖）
  3. stock 运行时        精确匹配 electron-v${ELECTRON_VERSION:-<探测版>}-linux-arm64.zip（本地/下载/缓存）
  4. asar 解包           $APP_DIR/resources/app（平铺，等价 asar:false）
  5. 原生模块回填        koffi/rg 零动作 + node-pty npm 变体 + better-sqlite3 GitHub prebuild
  5.5 遥测处理           $stub_plan
  6. 启动器              $APP_DIR/start.sh + alias workbuddy
EOF
  exit 0
fi

do_install "$dmg_path"
