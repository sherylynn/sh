#!/bin/bash
# ==============================================================================
# build_kwin_debug.sh —— anland KWin / Xwayland 调试版构建器 (Debian 13 / aarch64)
#
# 行为与 anland 官方 producers/kde/Debian13_v5/build.sh 保持一致，但做了
# 以下关键增强以支持调试：
#   1. 自动通过 HTTP 代理拉取 anland 仓库（默认 127.0.0.1:10808）
#   2. dpkg-buildpackage 后同时收集 *.deb 和 *.ddeb（漏抓是官方脚本的老问题）
#   3. 可选 DEBUG=1：注入 -O0 -g3 禁用优化 + 最大调试符号
#   4. 可选 --no-install：只产出包、不立刻 dpkg -i 安装到系统
#   5. 跳过官方 build.sh 末尾那条删 PULSE_SERVER=unix:/tmp/.pulse-socket 的 sed
#
# 用法:
#   ./build_kwin_debug.sh                        # 默认：-O2 -g 官方级别，生成 dbgsym.ddeb
#   DEBUG=1 ./build_kwin_debug.sh                # 开 -O0 -g3（栈/变量完整，体积翻 3~5 倍）
#   DEBUG=1 ./build_kwin_debug.sh --no-install   # 只出包，不安装
#   OUTPUT_DIR=$HOME/kwin-debug-packages ./build_kwin_debug.sh
# ==============================================================================
set -u

# -------- 可调参数（都可通过环境变量覆盖） ------------------------------------
ANLAND_REPO="${ANLAND_REPO:-https://github.com/superturtlee/anland.git}"
ANLAND_REF="${ANLAND_REF:-main}"
HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:10808}"
HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:10808}"
WORKDIR="${WORKDIR:-$HOME/anland-debbuild-debug}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/anland-debug-packages}"
JOBS="${JOBS:-$(nproc)}"
DEBUG="${DEBUG:-0}"

INSTALL_PKGS=1
for arg in "$@"; do
    case "$arg" in
        --no-install) INSTALL_PKGS=0 ;;
        -h|--help)
            sed -n '2,22p' "$0"
            exit 0
            ;;
        *) echo "未知参数: $arg"; exit 2 ;;
    esac
done

# -------- 工具与前置检查 -----------------------------------------------------
log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn] %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[error] %s\033[0m\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

need_cmd apt-get || die "缺少命令: apt-get（仅支持 Debian/Ubuntu 系）"

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else
    command -v sudo >/dev/null 2>&1 || die "非 root 且系统无 sudo，无法安装构建工具"
    SUDO="sudo"
fi

case "$(uname -m)" in
    aarch64|arm64) ;;
    *) echo "[warn] 当前架构 $(uname -m) 不是 aarch64，构建产物可能无法在 Droidspaces 使用，10s 后继续 ..."
       sleep 10 ;;
esac

export http_proxy="$HTTP_PROXY" https_proxy="$HTTPS_PROXY"
export HTTP_PROXY HTTPS_PROXY
# apt 也走代理（默认走环境变量即可，部分系统需显式配置则跳过）
export apt_http_proxy="$HTTP_PROXY" apt_https_proxy="$HTTPS_PROXY"

# -------- 自动补齐最小构建工具链 --------------------------------------------
# dpkg-buildpackage 来自 dpkg-dev；debchange/dh_* 来自 devscripts+debhelper
ensure_build_tools() {
    local missing=()
    need_cmd git               || missing+=(git ca-certificates)
    need_cmd patch             || missing+=(patch)
    need_cmd fakeroot          || missing+=(fakeroot)
    need_cmd dpkg-buildpackage || missing+=(dpkg-dev build-essential)
    need_cmd debchange         || missing+=(devscripts)
    need_cmd dh_strip          || missing+=(debhelper dh-strip-nondeterminism)
    need_cmd cmake             || missing+=(cmake extra-cmake-modules)

    if ((${#missing[@]} == 0)); then
        return 0
    fi

    local -a uniq_pkgs=()
    local -A _seen=()
    local p
    for p in "${missing[@]}"; do
        if [ -z "${_seen[$p]:-}" ]; then
            uniq_pkgs+=("$p")
            _seen[$p]=1
        fi
    done
    log "自动安装构建工具: ${uniq_pkgs[*]}"
    $SUDO apt-get update -qq || true
    $SUDO apt-get install -y --no-install-recommends "${uniq_pkgs[@]}" \
        || die "apt-get install 构建工具失败（检查代理/网络）"
}
ensure_build_tools

# 最终兜底校验（防止 apt 虽成功但个别命令仍缺失）
need_cmd git               || die "git 仍不可用"
need_cmd patch             || die "patch 仍不可用"
need_cmd fakeroot          || die "fakeroot 仍不可用"
need_cmd dpkg-buildpackage || die "dpkg-buildpackage 仍不可用（dpkg-dev 未装好?）"
need_cmd debchange         || die "debchange 仍不可用（devscripts 未装好?）"
need_cmd dh_strip          || warn "debhelper/dh_strip 缺失，可能无法正确生成 -dbgsym.ddeb"

# -------- 1. 获取 anland 构建资源（自动探测 builder 目录） --------------------
ANLAND_SRC="$WORKDIR/_anland_src"
# 用户可通过 BUILDER_DIR=/xxx 直接指定已有目录，跳过 git clone 与探测
BUILDER_DIR="${BUILDER_DIR:-}"

# ---- 在一个根目录下搜索同时含 build.sh + kwin.patch + xwayland.patch 的子目录
_locate_builder_dirs() {
    local root="$1"
    [ -d "$root" ] || return 0
    # 优先级：先试最可能的硬编码路径
    local cand
    for cand in \
        "$root/producers/kde/Debian13_v5" \
        "$root/producers/kde" \
        "$root/kde/Debian13_v5" \
        "$root/kde" \
        "$root/anland/kde" \
        "$root"; do
        if [ -f "$cand/build.sh" ] && [ -f "$cand/kwin.patch" ] && [ -f "$cand/xwayland.patch" ]; then
            echo "$cand"
            return 0
        fi
    done
    # 全仓搜索：find 任何同时含 3 个文件的子目录
    find "$root" -type f -name build.sh 2>/dev/null | while read -r bs; do
        local d
        d="$(dirname "$bs")"
        if [ -f "$d/kwin.patch" ] && [ -f "$d/xwayland.patch" ]; then
            echo "$d"
        fi
    done | head -n 1
}

# ---- 打印找不到文件时的诊断：列出仓库结构 + 所有 patch / build.sh 位置
_dump_diagnostics() {
    local root="$1"
    local extra_fallback="${2:-}"
    {
        echo
        echo "======== 诊断信息 ========"
        echo "ANLAND_REPO = $ANLAND_REPO"
        echo "ANLAND_REF  = $ANLAND_REF"
        echo "搜索根目录  = $root"
        if [ -d "$root" ]; then
            echo
            echo "-- 根目录一级内容： --"
            ls -la "$root" 2>&1 | sed 's/^/   /' || true
            echo
            echo "-- 前三级含 kde/producer/build/patch 字样的路径： --"
            (find "$root" -maxdepth 4 \( -iname '*kde*' -o -iname '*producer*' -o -iname 'build.sh' -o -name '*.patch' \) -print 2>/dev/null | sort | head -n 80) | sed 's/^/   /'
            echo
            echo "-- 找到的 build.sh： --"
            (find "$root" -type f -name build.sh 2>/dev/null | sort | sed 's/^/   /' || true)
            echo "-- 找到的 kwin*.patch： --"
            (find "$root" -type f -name 'kwin*.patch' 2>/dev/null | sort | sed 's/^/   /' || true)
            echo "-- 找到的 xwayland*.patch： --"
            (find "$root" -type f -name 'xwayland*.patch' 2>/dev/null | sort | sed 's/^/   /' || true)
        else
            echo "  (根目录不存在)"
        fi
        if [ -n "$extra_fallback" ]; then
            echo
            echo "-- 额外 fallback 目录 ($extra_fallback)： --"
            if [ -d "$extra_fallback" ]; then
                ls -la "$extra_fallback" 2>&1 | sed 's/^/   /'
                echo "   找到的 build.sh:"
                (find "$extra_fallback" -type f -name build.sh 2>/dev/null | sort | sed 's/^/   /' || true)
                echo "   找到的 kwin*.patch:"
                (find "$extra_fallback" -type f -name 'kwin*.patch' 2>/dev/null | sort | sed 's/^/   /' || true)
            else
                echo "   (fallback 目录不存在)"
            fi
        fi
        echo "========================="
    } >&2
}

prepare_builder() {
    # 1) 若用户显式指定 BUILDER_DIR，直接信任它，完全跳过 clone
    if [ -n "$BUILDER_DIR" ]; then
        log "使用显式 BUILDER_DIR=$BUILDER_DIR（跳过 clone）"
        test -f "$BUILDER_DIR/build.sh"     || die "显式 BUILDER_DIR 下找不到 build.sh"
        test -f "$BUILDER_DIR/kwin.patch"   || die "显式 BUILDER_DIR 下找不到 kwin.patch"
        test -f "$BUILDER_DIR/xwayland.patch" || die "显式 BUILDER_DIR 下找不到 xwayland.patch"
        return 0
    fi

    log "准备 anland 构建脚本与 patch (ref=$ANLAND_REF)"
    rm -rf "${ANLAND_SRC:?}"
    mkdir -p "$WORKDIR"

    # 2) 直接全量浅克隆。仓库很小（<200KB），全量比 sparse 稳——官方仓库
    #    在 Debian13_v5/ 下用了 kwin -> ../anland_backend_debian13_v5 软链，
    #    sparse/cone mode 下容易拉不齐软链目标 + 把 CMakeLists.txt 当目录传
    #    给 sparse-checkout 会导致整个 set 命令失败，worktree 空掉。
    git clone --depth=1 --branch "$ANLAND_REF" "$ANLAND_REPO" "$ANLAND_SRC" 2>&1 \
        || die "git clone 失败 (代理是否已开启 127.0.0.1:10808?)"

    # 3) 快速路径：直接命中官方布局 producers/kde/Debian13_v5/
    local fast_path="$ANLAND_SRC/producers/kde/Debian13_v5"
    local found=""
    if [ -f "$fast_path/build.sh" ] && \
       [ -f "$fast_path/kwin.patch" ] && \
       [ -f "$fast_path/xwayland.patch" ] && \
       [ -L "$fast_path/kwin" ]; then
        found="$fast_path"
    fi

    # 4) 快速路径没命中，才启动全仓搜索（防御：防止将来改名 / 换分支）
    if [ -z "$found" ]; then
        found="$(_locate_builder_dirs "$ANLAND_SRC")"
    fi

    if [ -z "$found" ]; then
        # 5) 最终 fallback：搜索本机已有的 Droidspaces-rootfs-builder 目录
        local fallback_root="/root/sh/tmp/Droidspaces-rootfs-builder"
        found="$(_locate_builder_dirs "$fallback_root")"
        if [ -z "$found" ]; then
            _dump_diagnostics "$ANLAND_SRC" "$fallback_root"
            cat >&2 <<'EOF'

[提示] 在 ANLAND_REPO 里和本地 fallback 目录都找不到「同时含 build.sh + kwin.patch + xwayland.patch + kwin 软链」的目录。
可能的原因与解决：
  A. 仓库结构改了 / 路径变了：根据上方诊断列出的实际 patch 位置，设置：
         BUILDER_DIR=/path/to/dir ./build_kwin_debug.sh
  B. 用错了仓库（ANLAND_REPO 不是存 kwin patch 的那个）：设置正确的仓库：
         ANLAND_REPO=https://github.com/正确作者/正确仓库.git ./build_kwin_debug.sh
  C. 用错了分支：ANLAND_REF=feature_xxx ./build_kwin_debug.sh
  D. 本地 tmp 已有构建脚本：直接把 patch/build.sh 所在目录作为 BUILDER_DIR 传入即可。
EOF
            die "无法自动定位 kwin 构建脚本目录"
        fi
        warn "clone 的仓库里没找到构建资源，改用本地 fallback 目录: $found"
    fi

    BUILDER_DIR="$found"
    log "builder 目录定位成功: $BUILDER_DIR"

    # overlay：对齐官方 build.sh L91 行为 —— $BUILDER_DIR/kwin 是软链，
    # 官方通过 cp -a "$SCRIPT_DIR/kwin/." <src-tree> 合并整个 anland_backend。
    # 要求软链存在且可解（如果解出来的目录不存在就会 cp 失败，我们这里提前报）
    local overlay_target
    overlay_target="$(readlink -f "$BUILDER_DIR/kwin" 2>/dev/null || true)"
    if [ -L "$BUILDER_DIR/kwin" ] && [ -n "$overlay_target" ] && [ -d "$overlay_target" ]; then
        log "overlay 软链正常: $BUILDER_DIR/kwin -> $overlay_target"
    elif [ -d "$BUILDER_DIR/kwin" ]; then
        log "overlay 目录正常: $BUILDER_DIR/kwin（非软链，仍可工作）"
    else
        cat >&2 <<EOF
[error] 官方要求的 overlay 入口 '$BUILDER_DIR/kwin' 不存在或指向无效目录。
        官方布局：kwin 是软链 -> ../anland_backend_debian13_v5/
        请检查：
          1. 当前 ANLAND_REF=$ANLAND_REF 这个分支是否有 producers/kde/anland_backend_debian13_v5/
          2. BUILDER_DIR 下 'ls -l kwin' 的输出
EOF
        die "overlay 目录缺失"
    fi
}

# -------- 2. 打开 deb-src 源 -------------------------------------------------
ensure_deb_src() {
    log "确认 deb-src 源已启用（apt-get source 需要）"
    if ! $SUDO grep -rqsE '^Types:.*deb-src|^deb-src ' \
            /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        if [ -f /etc/apt/sources.list.d/debian.sources ]; then
            $SUDO sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/debian.sources
        elif [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
            $SUDO sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
        elif [ -f /etc/apt/sources.list ]; then
            $SUDO sed -i 's/^deb \(.*\)$/deb \1\ndeb-src \1/' /etc/apt/sources.list
        else
            die "找不到 apt 源配置文件，无法启用 deb-src"
        fi
    fi
    $SUDO apt-get update -qq || warn "apt-get update 有报错，尝试继续"
}

# -------- 3. 带 debug 选项的单包构建 -----------------------------------------
# $1=包名(kwin/xwayland)  $2=patch文件  $3=patch-sentinel
build_pkg_debug() {
    local src="$1" patch="$2" sentinel="${3:-}"
    local pkgdir="$WORKDIR/$src"
    rm -rf "${pkgdir:?}"; mkdir -p "$pkgdir"

    log "[${src}] 安装 build-dep"
    $SUDO apt-get build-dep -y "$src" || warn "build-dep 有警告，继续"

    log "[${src}] apt-get source"
    ( cd "$pkgdir" && apt-get source "$src" ) || die "apt-get source $src 失败"

    local tree
    tree="$(find "$pkgdir" -maxdepth 1 -type d -name "${src}-*" | head -1)"
    test -n "$tree" || die "找不到 $src 的解压源码目录"

    # ---- overlay（anland_backend_debian13_v5 / xwayland 本地文件覆盖） ------
    local overlay_dir="$BUILDER_DIR/$src"
    if [ -d "$overlay_dir" ]; then
        log "[${src}] 应用 overlay: $overlay_dir -> $tree"
        cp -a "$overlay_dir/." "$tree/"
    fi

    # ---- 打 patch ---------------------------------------------------------
    log "[${src}] 应用 patch: $patch"
    if ( cd "$tree" && patch -p1 --forward --reject-file=- < "$patch" ); then true; else
        if [ -n "$sentinel" ] && grep -rqF "$sentinel" "$tree" 2>/dev/null; then
            warn "patch 看起来已应用过，跳过"
        else
            die "patch 对 $src 应用失败"
        fi
    fi

    # ---- DEBUG=1: 注入 -O0 -g3 + 阻止 nostrip ----------------------------
    local extra_cflags="" extra_cxxflags="" extra_make_flags=""
    if [ "$DEBUG" = "1" ]; then
        extra_cflags="-O0 -g3 -ggdb3 -fno-omit-frame-pointer"
        extra_cxxflags="-O0 -g3 -ggdb3 -fno-omit-frame-pointer"
        log "[${src}] DEBUG=1: 注入 CFLAGS/CXXFLAGS='$extra_cflags'（禁用优化，符号更完整）"
    fi

    # ---- 构建（二进制 + dbgsym.ddeb） -------------------------------------
    # 关键:
    #   * DEB_BUILD_OPTIONS 不加 nostrip -> dh_strip 会自动生成 -dbgsym.ddeb
    #   * dpkg-buildpackage 用默认 -b 即可，dbgsym 包会落在 $pkgdir（源码包上一级）
    #   * -d 跳过 build-deps 重新检查; -uc -us 不签名
    log "[${src}] dpkg-buildpackage (JOBS=$JOBS, dbgsym=on)"
    (
        cd "$tree"
        export DEB_BUILD_OPTIONS="nocheck parallel=$JOBS"
        if [ -n "$extra_cflags" ]; then
            export DEB_CFLAGS_APPEND="$extra_cflags"
            export DEB_CXXFLAGS_APPEND="$extra_cxxflags"
            export DEB_LDFLAGS_APPEND="-fno-omit-frame-pointer"
        fi
        dpkg-buildpackage -b -uc -us -d
    ) || die "dpkg-buildpackage 失败 ($src)"

    # ---- 同时收集 *.deb 和 *.ddeb ----------------------------------------
    local pkgs
    mapfile -t pkgs < <(find "$pkgdir" -maxdepth 1 -type f \( -name '*.deb' -o -name '*.ddeb' \) | sort)
    ((${#pkgs[@]} > 0)) || die "$src 没有任何 .deb/.ddeb 产物"

    local dest="$OUTPUT_DIR/$src"
    mkdir -p "$dest"
    log "[${src}] 收集 ${#pkgs[@]} 个包 -> $dest"
    for p in "${pkgs[@]}"; do
        printf '  %s\n' "$(basename "$p")"
        cp -f "$p" "$dest/"
    done

    if [ "$INSTALL_PKGS" = "1" ]; then
        # 仅安装非 debug 包（ddeb 由用户按需安装，避免把系统装满 dbgsym）
        log "[${src}] 安装正式 deb（ddeb 请按需手动 dpkg -i）"
        local real_debs
        mapfile -t real_debs < <(find "$pkgdir" -maxdepth 1 -type f -name '*.deb' ! -name '*dbgsym*' | sort)
        if ((${#real_debs[@]} > 0)); then
            # shellcheck disable=SC2086
            $SUDO dpkg -i "${real_debs[@]}" || warn "dpkg -i $src 有报错（可能缺依赖，apt-get -f install 修复）"
        fi
    fi
}

# -------- 4. 主流程 ----------------------------------------------------------
main() {
    mkdir -p "$WORKDIR" "$OUTPUT_DIR"
    log "WORKDIR     = $WORKDIR"
    log "OUTPUT_DIR  = $OUTPUT_DIR"
    log "DEBUG       = $DEBUG"
    log "INSTALL     = $INSTALL_PKGS"
    log "HTTP_PROXY  = $HTTP_PROXY"

    prepare_builder
    ensure_deb_src

    build_pkg_debug kwin     "$BUILDER_DIR/kwin.patch"     "BackendType::Anland"
    build_pkg_debug xwayland "$BUILDER_DIR/xwayland.patch" "No usable linux-dmabuf main device"

    # （注意：不执行官方 build.sh L143 那条删 PULSE_SERVER 的 sed，保留用户环境）

    echo
    echo "===================================================================="
    echo " 构建完成！产物汇总（含 dbgsym.ddeb/.ddeb）："
    echo "===================================================================="
    (
        cd "$OUTPUT_DIR"
        for sub in kwin xwayland; do
            test -d "$sub" || continue
            echo
            echo "--- $sub/ ---"
            find "$sub" -maxdepth 1 -type f | sort | while read -r f; do
                printf '  %-55s  %s\n' "$(basename "$f")" "$(du -h "$f" | cut -f1)"
            done
        done
    )
    echo
    echo "调试建议："
    echo "  1) 安装主包（已自动安装，如使用了 --no-install 请手动）"
    echo "       dpkg -i $OUTPUT_DIR/kwin/*.deb $OUTPUT_DIR/xwayland/*.deb"
    echo "  2) 安装对应 dbgsym 符号包（gdb 自动加载调试符号用）"
    echo "       dpkg -i $OUTPUT_DIR/kwin/*dbgsym*.ddeb $OUTPUT_DIR/xwayland/*dbgsym*.ddeb"
    echo "  3) 重启 KDE/KWin 会话后 gdb 挂 kwin_wayland："
    echo "       gdb -p \$(pidof kwin_wayland)"
    echo "       # 在 gdb 里可直接：bt   (调用栈)"
    echo "       #               info threads"
    echo "       #               set debug-file-directory /usr/lib/debug"
    echo "  4) 若 DEBUG=0 包符号不足则重跑：DEBUG=1 $0"
}

main "$@"
