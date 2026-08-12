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

if ((rebuild_native == 1)); then
	rebuild_better_sqlite
fi

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
