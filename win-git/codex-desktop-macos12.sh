#!/usr/bin/env bash
set -Eeuo pipefail

# 在 macOS 12 Monterey 上运行 ChatGPT Desktop 的实验性构建脚本。
# 原理：保留官方 DMG 中的 app.asar 和资源，只替换为支持 macOS 12 的 Electron 运行时。

readonly DEFAULT_DMG="${HOME}/Downloads/ChatGPT.dmg"
readonly DEFAULT_OUTPUT="${HOME}/Applications/ChatGPT macOS 12.app"
readonly DEFAULT_ELECTRON_VERSION="43.2.0"
readonly DEFAULT_ELECTRON_MIRROR="https://github.com/electron/electron/releases/download"
readonly DEFAULT_WORK_ROOT="${HOME}/tools/codex-desktop"

dmg_path="${CODEX_DMG_PATH:-$DEFAULT_DMG}"
output_app="${CODEX_MACOS12_APP:-$DEFAULT_OUTPUT}"
electron_version="${ELECTRON_VERSION:-$DEFAULT_ELECTRON_VERSION}"
electron_zip="${ELECTRON_ZIP:-}"
electron_mirror="${ELECTRON_MIRROR:-$DEFAULT_ELECTRON_MIRROR}"
work_root="${CODEX_MACOS12_WORK_ROOT:-$DEFAULT_WORK_ROOT}"
work_dir="${CODEX_MACOS12_WORK:-}"
keep_work=0
skip_sign=0
dry_run=0
rebuild_native=1

die() {
	printf '错误：%s\n' "$*" >&2
	exit 1
}
info() { printf '\n==> %s\n' "$*"; }

usage() {
	cat <<'EOF'
用法：codex-desktop-macos12.sh [选项]

将官方 ChatGPT.dmg 的应用资源与 macOS 12 可运行的 Electron 组合，生成本地 .app。

选项：
  --dmg FILE       指定 DMG（默认：~/Downloads/ChatGPT.dmg）
  --output APP     输出 .app（默认：~/Applications/ChatGPT macOS 12.app）
  --electron VER   Electron 版本（默认：43.2.0）
  --electron-zip   使用本地 Electron darwin-arm64/darwin-x64 ZIP
  --work DIR       指定并保留工作目录，便于排查
  --no-sign        不进行本地 ad-hoc 签名
  --no-native      不重编译 better-sqlite3（不建议）
  --dry-run        只检查参数和依赖，不构建
  -h, --help       显示帮助

也可以通过环境变量设置：CODEX_DMG_PATH、CODEX_MACOS12_APP、ELECTRON_VERSION、
ELECTRON_ZIP、ELECTRON_MIRROR、CODEX_MACOS12_WORK_ROOT、CODEX_MACOS12_WORK。

默认在 ~/tools/codex-desktop 下构建；结束后自动删除本次临时目录，
下载的 Electron ZIP 保留在 cache/electron 中供后续构建复用。
EOF
}

while (($#)); do
	case "$1" in
	--dmg)
		(($# >= 2)) || die "--dmg 需要文件路径"
		dmg_path="$2"
		shift 2
		;;
	--output)
		(($# >= 2)) || die "--output 需要路径"
		output_app="$2"
		shift 2
		;;
	--electron)
		(($# >= 2)) || die "--electron 需要版本"
		electron_version="$2"
		shift 2
		;;
	--electron-zip)
		(($# >= 2)) || die "--electron-zip 需要文件路径"
		electron_zip="$2"
		shift 2
		;;
	--work)
		(($# >= 2)) || die "--work 需要目录"
		work_dir="$2"
		keep_work=1
		shift 2
		;;
	--no-sign)
		skip_sign=1
		shift
		;;
	--no-native)
		rebuild_native=0
		shift
		;;
	--dry-run)
		dry_run=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*) die "未知选项：$1" ;;
	esac
done

[[ "$(uname -s)" == "Darwin" ]] || die "此脚本只能在 macOS 上运行。"
case "$(sw_vers -productVersion)" in
12.*) ;;
*) die "此脚本目标是 macOS 12，当前系统为 $(sw_vers -productVersion)。" ;;
esac
[[ -f "$dmg_path" ]] || die "找不到 DMG：$dmg_path"
command -v curl >/dev/null 2>&1 || die "缺少 curl。"
command -v unzip >/dev/null 2>&1 || die "缺少 unzip。"
command -v ditto >/dev/null 2>&1 || die "缺少 ditto。"

case "$(uname -m)" in
arm64) electron_arch=arm64 ;;
x86_64) electron_arch=x64 ;;
*) die "不支持的 CPU 架构：$(uname -m)" ;;
esac

if ! command -v 7zz >/dev/null 2>&1 && ! command -v 7z >/dev/null 2>&1; then
	command -v brew >/dev/null 2>&1 || die "缺少 7zz/7z，且找不到 Homebrew；请先安装 Homebrew。"
	info "未找到 7zz/7z，使用 Homebrew 安装 sevenzip"
	brew install sevenzip
	command -v 7zz >/dev/null 2>&1 || command -v 7z >/dev/null 2>&1 || die "sevenzip 安装后仍找不到 7zz/7z。"
fi

if ((rebuild_native == 1)); then
	command -v brew >/dev/null 2>&1 || die "重编译原生模块需要 Homebrew。"
	if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
		info "使用 Homebrew 安装原生模块构建依赖：node"
		brew install node
	fi
	if ! brew list --formula llvm >/dev/null 2>&1; then
		info "使用 Homebrew 安装原生模块构建依赖：llvm"
		brew install llvm
	fi
	command -v node >/dev/null 2>&1 || die "安装 node 后仍找不到 node。"
	command -v npm >/dev/null 2>&1 || die "安装 node 后仍找不到 npm。"
fi

if [[ -z "$work_dir" ]]; then
	mkdir -p "$work_root/build" "$work_root/cache/electron"
	work_dir=$(mktemp -d "$work_root/build/codex-macos12.XXXXXX")
else
	mkdir -p "$work_dir"
fi

cleanup() {
	if ((keep_work == 0)); then
		rm -rf "$work_dir"
	else
		info "工作目录已保留：$work_dir"
	fi
}
trap cleanup EXIT

if ((dry_run)); then
	info "检查通过"
	printf 'DMG：%s\n输出：%s\nElectron：%s (%s)\n工作目录：%s\n' \
		"$dmg_path" "$output_app" "$electron_version" "$electron_arch" "$work_dir"
	exit 0
fi

electron_zip_path="$work_dir/electron.zip"
if [[ -n "$electron_zip" ]]; then
	[[ -f "$electron_zip" ]] || die "找不到 Electron ZIP：$electron_zip"
	cp "$electron_zip" "$electron_zip_path"
else
	electron_filename="electron-v${electron_version}-darwin-${electron_arch}.zip"
	electron_cache="$work_root/cache/electron/$electron_filename"
	if [[ -f "$electron_cache" ]]; then
		info "复用 Electron 缓存：$electron_cache"
		cp "$electron_cache" "$electron_zip_path"
	else
		electron_url="${electron_mirror}/v${electron_version}/$electron_filename"
		info "下载 Electron ${electron_version} (${electron_arch})"
		# GitHub 偶尔会在旧版 macOS 的 TLS 握手阶段断开，所有瞬时错误统一重试。
		curl --fail --location --retry 5 --retry-all-errors --retry-delay 2 \
			--output "$electron_zip_path" "$electron_url" ||
			die "Electron 下载失败，可使用 --electron-zip 指定本地 ZIP。"
		mkdir -p "$(dirname "$electron_cache")"
		cp "$electron_zip_path" "$electron_cache"
	fi
fi

electron_dir="$work_dir/electron"
mkdir -p "$electron_dir"
unzip -q "$electron_zip_path" -d "$electron_dir"
electron_app=$(find "$electron_dir" -type d -name 'Electron.app' -print -quit)
[[ -n "$electron_app" ]] || die "Electron ZIP 中没有 Electron.app。"
readonly RUNTIME_EXECUTABLE="ChatGPT"

info "解包官方 DMG"
dmg_dir="$work_dir/dmg"
mkdir -p "$dmg_dir"
extractor=7zz
command -v "$extractor" >/dev/null 2>&1 || extractor=7z
# DMG 内含应用安装器和 Node 模块符号链接；-snl 让 7-Zip 按链接处理。
# 7-Zip 对 DMG 中的绝对符号链接会返回警告状态 2，但主体应用仍会被正确提取。
set +e
"$extractor" x -y -snl "$dmg_path" "-o$dmg_dir" >/dev/null
extract_status=$?
set -e
source_app=$(find "$dmg_dir" -type d -name '*.app' -print -quit)
[[ -n "$source_app" ]] || die "DMG 解包失败（7zz 状态：$extract_status），没有找到 .app。"
source_resources="$source_app/Contents/Resources"
[[ -f "$source_resources/app.asar" ]] || die "源应用中没有 Contents/Resources/app.asar。"

info "组装 macOS 12 应用"
rm -rf "$output_app"
mkdir -p "$(dirname "$output_app")"
ditto "$electron_app" "$output_app"

# Electron.app 默认以 Electron 可执行文件启动时会被识别为开发环境（app.isPackaged=false），
# 进而尝试连接不存在的 localhost:5175。改成正式应用可执行文件名后才会加载 app:// 页面。
mv "$output_app/Contents/MacOS/Electron" "$output_app/Contents/MacOS/$RUNTIME_EXECUTABLE"

# app.asar 是官方应用主体；Electron 自带的 default_app.asar 不能替代它。
cp "$source_resources/app.asar" "$output_app/Contents/Resources/app.asar"
if [[ -d "$source_resources/app.asar.unpacked" ]]; then
	ditto "$source_resources/app.asar.unpacked" "$output_app/Contents/Resources/app.asar.unpacked"
fi

# 同步官方资源，但不覆盖旧 Electron 自己的运行时文件。
for resource in "$source_resources"/*; do
	[[ -e "$resource" ]] || continue
	name=$(basename "$resource")
	case "$name" in
	app.asar | app.asar.unpacked | default_app.asar) continue ;;
	esac
	ditto "$resource" "$output_app/Contents/Resources/$name"
done

# Electron ZIP 不包含官方应用的 Sparkle 更新框架；复制官方框架后，更新器才能正常加载。
if [[ -d "$source_app/Contents/Frameworks/Sparkle.framework" ]]; then
	ditto "$source_app/Contents/Frameworks/Sparkle.framework" "$output_app/Contents/Frameworks/Sparkle.framework"
fi

rebuild_better_sqlite() {
	local app_asar="$source_resources/app.asar"
	local metadata_dir="$work_dir/better-sqlite3-metadata"
	local package_dir="$work_dir/better-sqlite3-source"
	local package_version package_tarball target_node llvm_prefix
	mkdir -p "$metadata_dir"

	# @electron/asar 的 extract-file 会把文件写到当前目录，故在独立目录中执行。
	(cd "$metadata_dir" && npx --yes @electron/asar extract-file "$app_asar" node_modules/better-sqlite3/package.json)
	[[ -s "$metadata_dir/package.json" ]] || die "无法从 app.asar 读取 better-sqlite3 版本。"
	package_version=$(node -p "require('$metadata_dir/package.json').version")
	[[ -n "$package_version" ]] || die "无法确定 better-sqlite3 版本。"

	info "为 Electron ${electron_version} 重编译 better-sqlite3 ${package_version}"
	mkdir -p "$package_dir"
	(cd "$package_dir" && npm pack "better-sqlite3@${package_version}" >/dev/null)
	package_tarball=$(find "$package_dir" -maxdepth 1 -name "better-sqlite3-${package_version}.tgz" -print -quit)
	[[ -f "$package_tarball" ]] || die "没有找到 better-sqlite3 源码包。"
	mkdir -p "$package_dir/unpacked"
	tar -xzf "$package_tarball" -C "$package_dir/unpacked"
	package_dir="$package_dir/unpacked/package"

	# Electron 43 的 V8 External API 增加了外部指针 tag；这些兼容改动只作用于构建副本。
	perl -0pi -e 's/\n\s*0,\n\s*data\n/\n\t\tnullptr,\n\t\tdata\n/' "$package_dir/src/util/helpers.cpp"
	perl -0pi -e 's/(#define OnlyAddon[^\n]*->Value)\(\)/$1(v8::kExternalPointerTypeTagDefault)/' "$package_dir/src/util/macros.cpp"
	perl -0pi -e 's/External::New\(isolate, addon\)/External::New(isolate, addon, v8::kExternalPointerTypeTagDefault)/g' "$package_dir/src/better_sqlite3.cpp"

	llvm_prefix=$(brew --prefix llvm)
	(
		cd "$package_dir"
		export CC="$llvm_prefix/bin/clang"
		export CXX="$llvm_prefix/bin/clang++"
		export CXXFLAGS="-std=c++20 -stdlib=libc++ -isystem $llvm_prefix/include/c++/v1"
		export LDFLAGS="-L$llvm_prefix/lib/c++ -Wl,-rpath,$llvm_prefix/lib/c++"
		npm_config_runtime=electron \
			npm_config_target="$electron_version" \
			npm_config_disturl=https://electronjs.org/headers \
			npm_config_build_from_source=true \
			npm run build-release
	)
	target_node="$output_app/Contents/Resources/app.asar.unpacked/node_modules/better-sqlite3/build/Release/better_sqlite3.node"
	[[ -f "$package_dir/build/Release/better_sqlite3.node" ]] || die "better-sqlite3 编译产物不存在。"
	[[ -f "$target_node" ]] || die "输出应用中没有 better-sqlite3 原生模块。"
	cp "$target_node" "${target_node}.original"
	cp "$package_dir/build/Release/better_sqlite3.node" "$target_node"
}

# 新版 ChatGPT/Codex（26.903+）的 app.asar 要求宿主是 OpenAI 定制的 Electron
# （内部代号 Owl，对外为 Codex Framework.framework）。官方包做了两道限制：
#   1) 校验 app.showTaskManager，缺失则抛
#      "Codex requires the Owl app shell; stock Electron is no longer supported."
#   2) 运行时直接调用 Owl 私有 API（BrowserWindow.is*Supported、
#      session.setPreferredLanguages 等），stock Electron 上缺失即崩溃。
# 这里注入兼容层，并把校验语句改写为引入兼容层（等长替换，不破坏 asar 结构）。
patch_owl_shell() {
	local app_asar="$output_app/Contents/Resources/app.asar"
	local unpacked_dir="$output_app/Contents/Resources/app.asar.unpacked"
	[[ -f "$app_asar" ]] || die "缺少 app.asar：$app_asar"
	mkdir -p "$unpacked_dir"

	info "注入 Owl app shell 兼容层"
	cat >"$unpacked_dir/owl-shim.js" <<'OWL_SHIM'
// Owl app shell 兼容层
// ---------------------------------------------------------------------------
// 新版 ChatGPT/Codex 官方包（26.903+）的 app.asar 要求宿主是 OpenAI 定制的
// Electron（内部代号 Owl / 对外为 Codex Framework.framework），做了两道限制：
//   1) 运行时校验 app.showTaskManager 存在，否则抛
//      "Codex requires the Owl app shell; stock Electron is no longer supported."
//   2) 运行时直接调用 Owl 私有 API（BrowserWindow.is*Supported、
//      session.setPreferredLanguages 等），缺失即崩溃。
//
// 本文件为 stock Electron 补齐这些私有 API，使其能继续启动。
//
// 实现要点：
//   - 打包器（esbuild/vite）会把 electron 模块包装成副本，因此"替换导出对象属性"
//     （例如让 BrowserWindow 指向 Proxy）不生效；必须把方法写到**原始对象**上，
//     副本与原始对象共享同一引用，这样才有效。
//   - Electron 的 session 只能在 app ready 之后访问
//     （否则抛 "Session can only be received when app is ready"），
//     因此 Session 的补齐必须延迟到 whenReady 回调中。
//   - 能力查询类 API 返回 undefined（= false），让调用方走"不支持"的降级分支，
//     功能减弱但不会崩溃。
//   - macOS 12 上 GPU/网络子进程沙箱初始化失败会导致
//     FATAL "GPU process isn't usable"，故默认关闭沙箱，双击 .app 即可启动。
//
// 由 codex-desktop-macos12.sh 生成，被 app.asar 内早期入口以绝对路径 require。
(function () {
  try {
    var e = require('electron');
    var noop = function () { return undefined; };

    // macOS 12：关闭子进程沙箱，避免 GPU 进程反复崩溃后被判定不可用而退出
    try { e.app.commandLine.appendSwitch('no-sandbox'); } catch (x) {}

    // 需要补齐的静态/单例 API
    var patchStatic = {
      app: [
        'showTaskManager',
        'setDebugChromePagesEnabled',
        'setRuntimeFeatures',
        'isRuntimeFeatureEnabled',
        'beginNativeMenuTracking',
        'endNativeMenuTracking',
        'hideOthers',
        'showAll'
      ],
      BrowserWindow: [
        'isAlwaysOnTopSupported',
        'isInputShapeSupported',
        'isSystemBackdropSupported'
      ],
      Notification: ['getPermissionStatus'],
      systemPreferences: ['getFontFamilies'],
      session: ['clearForLogout']
    };

    // 需要补齐的实例方法（写到原型上，对所有实例生效）
    var patchProto = {
      webContents: [
        'setPageCapturePaintLeaseEnabled',
        'getExtensionActions',
        'showExtensionActionContextMenu',
        'triggerExtensionAction'
      ]
    };

    // 归属对象不确定的私有 API：在多个候选宿主上都补（补在不存在的位置无害）
    var ambiguous = ['setPreferredLanguages', 'getDownloadHistory'];

    function apply(target, names) {
      if (!target) return;
      for (var i = 0; i < names.length; i++) {
        var n = names[i];
        if (n in target) continue;
        try {
          target[n] = noop;
        } catch (x) {
          try { Object.defineProperty(target, n, { value: noop, configurable: true }); } catch (y) {}
        }
      }
    }

    Object.keys(patchStatic).forEach(function (k) { apply(e[k], patchStatic[k]); });
    Object.keys(patchProto).forEach(function (k) {
      var C = e[k];
      if (C && C.prototype) apply(C.prototype, patchProto[k]);
    });

    // 立即补齐：app / webContents 原型 / 所有导出对象及其原型（尽力而为）
    apply(e.app, ambiguous);
    if (e.webContents && e.webContents.prototype) apply(e.webContents.prototype, ambiguous);
    try {
      Object.keys(e).forEach(function (k) {
        try {
          var v = e[k];
          if (v == null) return;
          try { apply(v, ambiguous); } catch (x) {}
          try { if (typeof v === 'function' && v.prototype) apply(v.prototype, ambiguous); } catch (x) {}
        } catch (x) {}
      });
    } catch (err) {}

    // 延迟补齐：Session 只能在 app ready 后访问。
    // shim 比启动流程更早注册 whenReady，因此本回调会先于业务代码执行。
    try {
      e.app.whenReady().then(function () {
        try {
          var ds = e.session && e.session.defaultSession;
          var proto = ds && ds.constructor && ds.constructor.prototype;
          if (proto) apply(proto, ambiguous);
        } catch (x) {}
      });
    } catch (x) {}
  } catch (err) {}
})();
OWL_SHIM

	info "改写 app.asar 内的 Owl shell 校验"
	OWL_APP_ASAR="$app_asar" node <<'PATCH_JS'
const fs = require('fs');
const file = process.env.OWL_APP_ASAR;
const buf = fs.readFileSync(file);
const marker = 'Codex requires the Owl app shell';
const m = buf.indexOf(Buffer.from(marker, 'utf8'));
if (m < 0) {
  console.log('未发现 Owl shell 校验（官方可能已放宽），跳过改写');
  process.exit(0);
}
// 校验语句形如：if(<条件>)throw Error(`Codex requires the Owl app shell; ...`);
// 以 marker 为锚点向前找 if( 、向后找语句结尾，避免依赖压缩后的变量名。
const ifIdx = buf.lastIndexOf(Buffer.from('if(', 'utf8'), m);
if (ifIdx < 0) { console.error('未找到校验语句起点 if('); process.exit(1); }
const tailIdx = buf.indexOf(Buffer.from('`);', 'utf8'), m);
if (tailIdx < 0) { console.error('未找到校验语句结尾'); process.exit(1); }
const end = tailIdx + 3;
const span = end - ifIdx;
const stmt = 'require(process.resourcesPath+"/app.asar.unpacked/owl-shim.js");';
if (stmt.length > span) {
  console.error('可用空间不足：需要 ' + stmt.length + ' 字节，实际 ' + span + ' 字节');
  process.exit(1);
}
buf.fill(0x20, ifIdx, end);
Buffer.from(stmt, 'utf8').copy(buf, ifIdx);
fs.writeFileSync(file, buf);
console.log('已改写 Owl 校验 -> 引入兼容层（可用 ' + span + ' 字节，使用 ' + stmt.length + ' 字节）');
PATCH_JS
}

if ((rebuild_native == 1)); then
	rebuild_better_sqlite
fi

# 官方包已改用 Owl shell，stock Electron 必须打兼容层才能启动。
patch_owl_shell

# 使用官方应用名称和图标，最低系统版本改为 Monterey；这不是绕过 Electron 框架检查，
# 真正的兼容性来自 Electron 43 的 Chromium/原生框架。
if [[ -f "$source_app/Contents/Info.plist" ]]; then
	source_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$source_app/Contents/Info.plist" 2>/dev/null || printf 'com.openai.codex')
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $RUNTIME_EXECUTABLE" "$output_app/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Set :CFBundleName ChatGPT" "$output_app/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $source_bundle_id" "$output_app/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$source_app/Contents/Info.plist" >/dev/null 2>&1 &&
		/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ChatGPT (macOS 12)" "$output_app/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion 12.0" "$output_app/Contents/Info.plist" 2>/dev/null || true
fi

if [[ -d "$source_app/Contents/Resources" ]]; then
	icon_file=$(find "$source_app/Contents/Resources" -name '*.icns' -print -quit)
	[[ -z "$icon_file" ]] || cp "$icon_file" "$output_app/Contents/Resources/$(basename "$icon_file")"
fi

# 删除下载隔离属性，随后用 ad-hoc 签名使本地开发版更容易启动。
xattr -dr com.apple.quarantine "$output_app" 2>/dev/null || true
if ((skip_sign == 0)) && command -v codesign >/dev/null 2>&1; then
	info "执行本地 ad-hoc 签名"
	codesign --deep --force --verbose --sign - "$output_app" >/dev/null ||
		die "签名失败，可使用 --no-sign 跳过。"
fi

launcher="${output_app%.app}.sh"
cat >"$launcher" <<EOF
#!/usr/bin/env bash
exec "${output_app}/Contents/MacOS/$RUNTIME_EXECUTABLE" --user-data-dir="\${CODEX_MACOS12_DATA:-\$HOME/Library/Application Support/ChatGPT-macOS12}" "\$@"
EOF
chmod +x "$launcher"

info "构建完成"
printf '应用：%s\n启动：%s\n' "$output_app" "$launcher"
printf '首次启动若被 Gatekeeper 拦截，可在“系统设置/安全性与隐私”中允许，或运行启动脚本。\n'
