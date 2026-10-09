#!/usr/bin/env bash
set -Eeuo pipefail

# 从 OpenAI 官方 Debian 仓库取得最新 ChatGPT/Codex Electron 主体，
# 与已在 Monterey 验证的 Darwin seed 组合，再换入支持 macOS 12 的 Electron。

readonly DEFAULT_DEBIAN_REPO="https://persistent.oaistatic.com/codex-app-prod/linux/deb"
readonly DEFAULT_SEED="${HOME}/Applications/ChatGPT macOS 12 Debian MCPMemory.app"
readonly DEFAULT_OUTPUT="${HOME}/Applications/ChatGPT macOS 12 Debian MCPMemory.app"
readonly DEFAULT_ELECTRON_VERSION="43.2.0"
readonly DEFAULT_ELECTRON_MIRROR="https://github.com/electron/electron/releases/download"
readonly DEFAULT_WORK_ROOT="${HOME}/tools/codex-desktop-from-debian"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

debian_repo="${CODEX_DEBIAN_REPO:-$DEFAULT_DEBIAN_REPO}"
deb_path="${CODEX_DEB_PATH:-}"
seed_app="${CODEX_MACOS12_SEED_APP:-$DEFAULT_SEED}"
output_app="${CODEX_MACOS12_DEBIAN_APP:-$DEFAULT_OUTPUT}"
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
用法：codex-desktop-macos12-from-debian.sh [选项]

从 OpenAI 官方 Debian 仓库下载最新 arm64 ChatGPT，将最新 Electron 主体移植到 macOS 12。

选项：
  --deb FILE       使用本地官方 .deb；省略时自动下载仓库最新版
  --seed APP       Darwin 资源来源（默认：~/Applications/ChatGPT macOS 12 Debian MCPMemory.app）
  --output APP     输出 .app（默认：~/Applications/ChatGPT macOS 12 Debian MCPMemory.app）
  --electron VER   Electron 版本（默认：43.2.0）
  --electron-zip   使用本地 Electron darwin-arm64/darwin-x64 ZIP
  --work DIR       指定并保留工作目录，便于排查
  --no-sign        不进行本地 ad-hoc 签名
  --no-native      不重编译 better-sqlite3（不建议）
  --dry-run        只检查参数和依赖，不构建
  -h, --help       显示帮助

也可以通过环境变量设置：CODEX_DEBIAN_REPO、CODEX_DEB_PATH、CODEX_MACOS12_SEED_APP、
CODEX_MACOS12_DEBIAN_APP、ELECTRON_VERSION、ELECTRON_ZIP、ELECTRON_MIRROR。

默认在 ~/tools/codex-desktop-from-debian 下构建；结束后自动删除本次临时目录，
下载的 Electron ZIP 保留在 cache/electron 中供后续构建复用。
来源与输出可以是同一个应用：构建前先复制来源快照，后续只读取快照。
EOF
}

while (($#)); do
	case "$1" in
	--deb)
		(($# >= 2)) || die "--deb 需要文件路径"
		deb_path="$2"
		shift 2
		;;
	--seed)
		(($# >= 2)) || die "--seed 需要应用路径"
		seed_app="$2"
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
[[ -f "$seed_app/Contents/Resources/app.asar" ]] || die "找不到有效 Darwin seed：$seed_app"
[[ -z "$deb_path" || -f "$deb_path" ]] || die "找不到 Debian 包：$deb_path"
command -v curl >/dev/null 2>&1 || die "缺少 curl。"
command -v ar >/dev/null 2>&1 || die "缺少 ar。"
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
	printf 'Debian：%s\nSeed：%s\n输出：%s\nElectron：%s (%s)\n工作目录：%s\n' \
		"${deb_path:-自动下载最新版}" "$seed_app" "$output_app" "$electron_version" "$electron_arch" "$work_dir"
	exit 0
fi

# 当前已安装应用也可同时作为输出。先保存完整快照，避免组装输出后再读取
# seed 时读到新包；原生模块恢复和后期 asar 提取均使用这个固定来源。
seed_original="$seed_app"
seed_snapshot="$work_dir/darwin-seed/ChatGPT.app"
mkdir -p "$(dirname "$seed_snapshot")"
info "保存 Darwin 资源来源快照"
ditto "$seed_original" "$seed_snapshot"
[[ -f "$seed_snapshot/Contents/Resources/app.asar" ]] || die "Darwin 来源快照不完整。"
seed_app="$seed_snapshot"

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
unzip -oq "$electron_zip_path" -d "$electron_dir"
electron_app=$(find "$electron_dir" -type d -name 'Electron.app' -print -quit)
[[ -n "$electron_app" ]] || die "Electron ZIP 中没有 Electron.app。"
readonly RUNTIME_EXECUTABLE="ChatGPT"

info "取得 OpenAI 官方 Debian 包"
if [[ -z "$deb_path" ]]; then
	packages_file="$work_dir/Packages"
	curl --fail --location --retry 5 --retry-all-errors --retry-delay 2 \
		"$debian_repo/dists/stable/main/binary-arm64/Packages" -o "$packages_file"
	deb_version=$(awk '/^Version:/{print $2;exit}' "$packages_file")
	deb_filename=$(awk '/^Filename:/{print $2;exit}' "$packages_file")
	deb_sha256=$(awk '/^SHA256:/{print $2;exit}' "$packages_file")
	[[ -n "$deb_version" && -n "$deb_filename" && -n "$deb_sha256" ]] || die "无法解析 Debian Packages。"
	mkdir -p "$work_root/cache/deb"
	deb_path="$work_root/cache/deb/chatgpt_${deb_version}_arm64.deb"
	if [[ ! -f "$deb_path" ]] || ! printf '%s  %s\n' "$deb_sha256" "$deb_path" | shasum -a 256 -c - >/dev/null 2>&1; then
		info "下载 ChatGPT Debian ${deb_version}"
		curl --fail --location --retry 5 --retry-all-errors --retry-delay 2 \
			"$debian_repo/$deb_filename" -o "$deb_path.part"
		printf '%s  %s\n' "$deb_sha256" "$deb_path.part" | shasum -a 256 -c - >/dev/null || die "Debian SHA256 校验失败。"
		mv "$deb_path.part" "$deb_path"
	fi
fi

deb_root="$work_dir/deb-root"
mkdir -p "$work_dir/deb-ar" "$deb_root"
(
	cd "$work_dir/deb-ar"
	ar x "$deb_path"
	data_archive=$(find . -maxdepth 1 -name 'data.tar.*' -print -quit)
	[[ -n "$data_archive" ]] || die "Debian 包没有 data.tar。"
	tar -xf "$data_archive" -C "$deb_root"
)
deb_resources="$deb_root/usr/lib/chatgpt/resources"
[[ -f "$deb_resources/app.asar" ]] || die "Debian 包没有 app.asar。"

# 以已经在 Monterey 启动验证过的 macOS 应用为 Darwin seed，再只覆盖可移植资源。
source_app="$work_dir/source/ChatGPT.app"
mkdir -p "$(dirname "$source_app")"
ditto "$seed_app" "$source_app"
source_resources="$source_app/Contents/Resources"
cp "$deb_resources/app.asar" "$source_resources/app.asar"
rm -rf "$source_resources/app.asar.unpacked"
ditto "$deb_resources/app.asar.unpacked" "$source_resources/app.asar.unpacked"

# Debian forge 只打入 Linux 平台 addon；恢复 seed 中 Darwin 平台 addon。
restore_seed_resource() {
	local rel="$1"
	[[ -e "$seed_app/Contents/Resources/$rel" ]] || return 0
	rm -rf "$source_resources/$rel"
	mkdir -p "$(dirname "$source_resources/$rel")"
	ditto "$seed_app/Contents/Resources/$rel" "$source_resources/$rel"
}
restore_seed_resource "app.asar.unpacked/node_modules/node-pty"
restore_seed_resource "app.asar.unpacked/node_modules/objc-js"
restore_seed_resource "app.asar.unpacked/node_modules/@parcel/watcher"
restore_seed_resource "app.asar.unpacked/node_modules/@parcel/watcher-darwin-arm64"
restore_seed_resource "app.asar.unpacked/node_modules/@worklouder/device-kit-oai/node_modules/@worklouder/wl-device-kit/dist/native/darwin"

# 同步最新跨平台数据；明确不把 Debian 的 ELF native/codex/cua_node 带进 macOS。
for name in accessibility artifact-template-picker plugin-signatures plugins skills; do
	[[ -e "$deb_resources/$name" ]] || continue
	rm -rf "$source_resources/$name"
	ditto "$deb_resources/$name" "$source_resources/$name"
done
for name in codex-classic.wav codex-notification.wav masque-proxy-origins.txt owl-app.ini; do
	[[ -f "$deb_resources/$name" ]] && cp "$deb_resources/$name" "$source_resources/$name"
done
# Owl 自己会覆盖 --user-data-dir；给实验版独立 profile，避免测试污染稳定版 Codex 数据。
if [[ -f "$source_resources/owl-app.ini" ]]; then
	perl -0pi -e 's/UserDataDirectoryName=Codex\r?\n/UserDataDirectoryName=Codex-macOS12-debian\r\n/' "$source_resources/owl-app.ini"
fi
meta_dir="$work_dir/debian-meta"
mkdir -p "$meta_dir"
(cd "$meta_dir" && npx --yes @electron/asar extract-file "$deb_resources/app.asar" package.json >/dev/null)
deb_app_version=$(node -p "require('$meta_dir/package.json').version")
deb_electron_version=$(node -p "require('$meta_dir/package.json').devDependencies.electron")
info "Debian 应用 ${deb_app_version}（上游 Electron ${deb_electron_version}），Darwin 资源来自 seed"

# 最新 Darwin 前端要求 Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex，
# 不能再沿用旧版 seed 的 Resources/codex。官方 npm 包提供同源 Darwin arm64 产物。
codex_version=$(npm view @openai/codex version)
[[ -n "$codex_version" ]] || die "无法读取 @openai/codex 最新版本。"
mkdir -p "$work_root/cache/codex"
codex_tgz="$work_root/cache/codex/openai-codex-${codex_version}-darwin-arm64.tgz"
if [[ ! -f "$codex_tgz" ]]; then
	info "下载 OpenAI Codex Darwin arm64 ${codex_version}"
	codex_pack_dir="$work_dir/codex-pack"
	mkdir -p "$codex_pack_dir"
	(cd "$codex_pack_dir" && npm pack "@openai/codex@${codex_version}-darwin-arm64" --silent >/dev/null)
	pack_file=$(find "$codex_pack_dir" -name '*.tgz' -print -quit)
	[[ -f "$pack_file" ]] || die "Codex Darwin npm 包下载失败。"
	cp "$pack_file" "$codex_tgz"
fi
codex_unpack="$work_dir/codex-darwin"
mkdir -p "$codex_unpack"
tar -xzf "$codex_tgz" -C "$codex_unpack"
codex_vendor="$codex_unpack/package/vendor/aarch64-apple-darwin"
[[ -x "$codex_vendor/bin/codex" ]] || die "Codex Darwin 包缺少 codex。"
# 同时保留根目录兼容入口，并建立新版 Darwin 前端要求的 CodexCLI.app 路径。
cp "$codex_vendor/bin/codex" "$source_resources/codex"
cp "$codex_vendor/bin/codex-code-mode-host" "$source_resources/codex-code-mode-host"
cp "$codex_vendor/codex-path/rg" "$source_resources/rg"
mkdir -p "$source_resources/codex-cli/CodexCLI.app/Contents/MacOS"
cp "$codex_vendor/bin/codex" "$source_resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
# 26.1002+ 的插件同步会把整个 codex-cli 包复制给本地原生宿主，并要求包根目录
# 存在元数据、code-mode helper 和 rg。仅伪造 CodexCLI.app 路径虽能启动主程序，
# 但会令 bundled plugins 在聚焦窗口时同步失败。
mkdir -p "$source_resources/codex-cli/bin" "$source_resources/codex-cli/codex-path" \
	"$source_resources/codex-cli/codex-resources"
cp "$codex_vendor/bin/codex-code-mode-host" "$source_resources/codex-cli/bin/codex-code-mode-host"
cp "$codex_vendor/codex-path/rg" "$source_resources/codex-cli/codex-path/rg"
cat >"$source_resources/codex-cli/codex-package.json" <<EOF
{
  "layoutVersion": 1,
  "version": "$codex_version",
  "target": "aarch64-apple-darwin",
  "variant": "codex",
  "entrypoint": "CodexCLI.app/Contents/MacOS/codex",
  "resourcesDir": "codex-resources",
  "pathDir": "codex-path"
}
EOF
chmod +x "$source_resources/codex" "$source_resources/codex-code-mode-host" "$source_resources/rg" \
	"$source_resources/codex-cli/CodexCLI.app/Contents/MacOS/codex" \
	"$source_resources/codex-cli/bin/codex-code-mode-host" "$source_resources/codex-cli/codex-path/rg"

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
	# Debian 原始 addon 是 ELF；不要把备份留在最终 macOS 应用中。
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
      screen: ['isCursorScreenPointSupported'],
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
    var ambiguous = ['setPreferredLanguages', 'getDownloadHistory', 'setWebsiteReportingEnabled', 'setPermissionPromptHandler'];

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

    // 新版前端会在 ready 之前通过 session-created 收到 Session，不能只补
    // defaultSession，否则 setWebsiteReportingEnabled 等私有 API 会发生竞态漏补。
    function patchSession(s) {
      if (!s) return;
      apply(s, ambiguous);
      try {
        var proto = s.constructor && s.constructor.prototype;
        if (proto) apply(proto, ambiguous);
      } catch (x) {}
    }
    try { e.app.on('session-created', patchSession); } catch (x) {}

    // 默认 Session 可能早于 shim 创建，收不到 session-created。包装 whenReady，
    // 确保所有后注册的业务回调运行前，它已经具备 Owl 私有 API。
    try {
      var originalWhenReady = e.app.whenReady.bind(e.app);
      var readyWithSessionPatch = originalWhenReady().then(function () {
        patchSession(e.session.defaultSession);
      });
      e.app.whenReady = function () { return readyWithSessionPatch; };
    } catch (x) {}
  } catch (err) {}
})();
OWL_SHIM

	# 新版 26.1002+ 在 Owl 校验之前就执行更多 Electron 初始化，因此旧的“校验点注入”
	# 已经太晚。解包并把 shim 放到 early-bootstrap 第一条语句，再重新打包；*.node 仍标记
	# 为 unpacked，实际 Darwin 二进制由上面的 app.asar.unpacked 提供。
	info "在 early-bootstrap 最前面注入 Owl shim"
	local asar_tree="$work_dir/asar-patched"
	local repacked="$work_dir/app-patched.asar"
	rm -rf "$asar_tree" "$repacked" "$repacked.unpacked"
	npx --yes @electron/asar extract "$app_asar" "$asar_tree"
	local bootstrap="$asar_tree/.vite/build/early-bootstrap.js"
	[[ -f "$bootstrap" ]] || die "app.asar 缺少 early-bootstrap.js。"
	# Linux asar 会裁掉 Darwin-only npm 包；只复制 .unpacked 不足以让 Node ESM 解析包名。
	# 从 Darwin seed 的 asar 解出完整 package.json/JS/native，再注入最新版 asar。
	local seed_asar_tree="$work_dir/seed-asar"
	rm -rf "$seed_asar_tree"
	npx --yes @electron/asar extract "$seed_app/Contents/Resources/app.asar" "$seed_asar_tree"
	for darwin_pkg in objc-js @parcel/watcher-darwin-arm64; do
		if [[ -d "$seed_asar_tree/node_modules/$darwin_pkg" ]]; then
			mkdir -p "$(dirname "$asar_tree/node_modules/$darwin_pkg")"
			ditto "$seed_asar_tree/node_modules/$darwin_pkg" "$asar_tree/node_modules/$darwin_pkg"
		fi
	done
	OWL_BOOTSTRAP="$bootstrap" OWL_BUILD_DIR="$asar_tree/.vite/build" node <<'PATCH_JS'
const fs=require('fs');
const path=require('path');
const f=process.env.OWL_BOOTSTRAP;
let src=fs.readFileSync(f,'utf8');
const stmt='require(process.resourcesPath+"/app.asar.unpacked/owl-shim.js");';
// stock Electron 没有 Owl 的网站报告开关；该能力不是网络请求的必要条件。
src=src.replaceAll('.setWebsiteReportingEnabled(', '.setWebsiteReportingEnabled?.(');
if(!src.startsWith(stmt)) src=stmt+src;
fs.writeFileSync(f,src);

// Owl 的权限提示回调在 stock Electron 中不存在；标准权限请求/检查处理器仍生效。
for (const name of fs.readdirSync(process.env.OWL_BUILD_DIR)) {
  if (!name.endsWith('.js')) continue;
  const file=path.join(process.env.OWL_BUILD_DIR,name);
  const before=fs.readFileSync(file,'utf8');
  const after=before
    .replaceAll('.setWebsiteReportingEnabled(', '.setWebsiteReportingEnabled?.(')
    .replaceAll('.setPermissionPromptHandler(', '.setPermissionPromptHandler?.(')
    .replaceAll('.setPreferredLanguages(', '.setPreferredLanguages?.(')
    // Owl 可查询全局光标能力；stock Electron 没有此探测 API。
    // 可选调用返回 undefined，使上层安全地跳过拖拽浮层宿主。
    .replaceAll('.isCursorScreenPointSupported()', '.isCursorScreenPointSupported?.()')
    // Owl 保存浏览器原生下载历史；stock Electron 仅提供当前下载事件。
    // 缺失时返回空历史，当前会话里的实时下载仍由原逻辑维护。
    .replaceAll('getDownloadHistory().catch(()=>null)', 'getDownloadHistory?.().catch(()=>null)??Promise.resolve(null)')
    .replaceAll('getDownloadHistory()).filter(NW)', 'getDownloadHistory?.()??[]).filter(NW)')
    // 动态应用工具 socket 已由宿主创建为 0600，消息还带临时 Ed25519 签名。
    // 移植包无法保留 Owl 的整包 Team ID 链，因此只对此 socket 使用同用户边界。
    .replaceAll('socketPeerAuthorizer:a=uf()', 'socketPeerAuthorizer:a=()=>({authorized:!0})');
  if(after!==before) fs.writeFileSync(file,after);
}
PATCH_JS

	# 将 Linux 端通过 CDP 实测确认的 MCP 内存修复直接打入 macOS 12 构建产物：
	# 1. Chat/本地线程不再渲染历史工具 activity 卡；
	# 2. 普通 Chat 的 ecosystem widget 在进入 mcp-sandbox-element 前返回 null，
	#    从源头阻止“一张历史 MCP 卡一个 Electron guest renderer”；Work 保留官方 widget；
	# 3. MCP App 专用 activity header 返回 null，清掉“正在打开/已打开/无法打开 mcp”残留行。
	# patch 使用当前官方 bundle 的唯一精确锚点；升级后结构不匹配就让构建失败，不猜 offset。
	node "$SCRIPT_DIR/patch-chatgpt-chat-mcp-activity.mjs" "$asar_tree/webview/assets"

	npx --yes @electron/asar pack "$asar_tree" "$repacked" --unpack "**/*.node"
	cp "$repacked" "$app_asar"
}

if ((rebuild_native == 1)); then
	rebuild_better_sqlite
fi

# 官方包已改用 Owl shell，stock Electron 必须打兼容层才能启动。
patch_owl_shell

# 使用官方应用名称和图标，最低系统版本改为 Monterey；这不是绕过 Electron 框架检查，
# 真正的兼容性来自 Electron 43 的 Chromium/原生框架。
if [[ -f "$source_app/Contents/Info.plist" ]]; then
	# 与现有稳定版使用不同 bundle id，允许两套构建并行做隔离验收。
	source_bundle_id="com.openai.codex.macos12.debian"
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $RUNTIME_EXECUTABLE" "$output_app/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Set :CFBundleName ChatGPT" "$output_app/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $source_bundle_id" "$output_app/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $deb_app_version" "$output_app/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $deb_app_version" "$output_app/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ChatGPT (macOS 12 Debian)" "$output_app/Contents/Info.plist" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion 12.0" "$output_app/Contents/Info.plist" 2>/dev/null || true
	cat >"$output_app/Contents/Resources/macos12-debian-build.txt" <<EOF
source=OpenAI Debian repository
debian_app_version=$deb_app_version
debian_declared_electron=$deb_electron_version
darwin_seed=$seed_original
runtime_electron=$electron_version
EOF
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
set -euo pipefail

# 默认保留 localhost-only CDP 调试入口，便于直接检查 MCP guest WebContents、renderer 和 DOM。
# CHATGPT_CDP_PORT=0 可关闭；不要把远程调试端口暴露到 LAN/WAN。
cdp_args=()
if [[ "\${CHATGPT_CDP_PORT:-9333}" != "0" ]]; then
	cdp_args+=(--remote-debugging-address=127.0.0.1 --remote-debugging-port="\${CHATGPT_CDP_PORT:-9333}")
fi
exec "${output_app}/Contents/MacOS/$RUNTIME_EXECUTABLE" \
	--user-data-dir="\${CODEX_MACOS12_DATA:-\$HOME/Library/Application Support/ChatGPT-macOS12}" \
	"\${cdp_args[@]}" "\$@"
EOF
chmod +x "$launcher"

info "构建完成"
printf '应用：%s\n启动：%s\n' "$output_app" "$launcher"
printf '首次启动若被 Gatekeeper 拦截，可在“系统设置/安全性与隐私”中允许，或运行启动脚本。\n'
