#!/bin/bash
. $(dirname "$0")/toolsinit.sh
AUTHOR=Genymobile
NAME=scrcpy
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
SOFT_HOME=$(install_path)/${NAME}
#SOFT_VERSION=$(get_github_release_version $AUTHOR/$NAME)
#SOFT_VERSION=v2.7
#SOFT_VERSION=v3.3.1
SOFT_VERSION=v4.1
#SOFT_VERSION=v3.0
#SOFT_VERSION=v3.0.2
#都很卡，离谱了
#2.7 的居然没有预编译的版本可以下载，离谱
echo "soft version is $SOFT_VERSION"
SOFT_ARCH=64

# 以管理员权限执行一条 shell 命令。
#   macOS -> 走系统认证弹窗（支持指纹/Touch ID），脚本里不会卡在 sudo 密码输入
#   其他   -> sudo
run_as_admin() {
  local cmd=$1
  if [[ $(platform) == *mac* ]] && command -v osascript >/dev/null 2>&1; then
    osascript -e "do shell script \"${cmd//\"/\\\"}\" with administrator privileges"
  else
    sudo sh -c "$cmd"
  fi
}

# meson 的 install prefix
meson_prefix() {
  local p
  p=$(meson configure x 2>/dev/null | awk '$1 == "prefix" { print $2; exit }')
  printf '%s' "${p:-/usr/local}"
}

# ---------- macOS: SDL3 依赖（scrcpy 4.x 起必须 SDL3） ----------
# scrcpy 4.1 的 app/meson.build 里是 dependency('sdl3', version: '>= 3.2.0')，
# sdl2 已经不够用了。Homebrew 的 sdl3 bottle 只面向它当前支持的 macOS 版本
# （minos 通常是 15.0 之类），macOS 12.4 这种旧系统上会出现两种情况：
#   1) brew 直接拒绝安装（Unsupported macOS version）；
#   2) 装上了但 dylib 的 minos 高于 12.4 —— meson 链接能过，运行期 dyld 拒绝加载。
# 因此对旧系统改为源码编译 SDL3：SDL3 官方要求 Xcode 12.2 + macOS 11 SDK 构建，
# 部署下限 10.13，macOS 12.4 的 Command Line Tools 完全满足。
# SCRCPY_SDL3_MODE=auto(默认) | brew(强制 homebrew，失败即退出) | source(强制源码编译)
SCRCPY_SDL3_MODE=${SCRCPY_SDL3_MODE:-auto}
# 留空时自动取 libsdl-org/SDL 的最新 release；也可以手动指定，如 SDL3_VERSION=3.2.0
SDL3_VERSION=${SDL3_VERSION:-}
SDL3_MIN_VERSION=3.2.0
SDL3_PREFIX=$(install_path)/SDL3

MACOS_VER=$(sw_vers -productVersion 2>/dev/null)
MACOS_MAJOR=${MACOS_VER%%.*}

# ver_ge a b -> a >= b（按 . 分段逐位比较，不依赖 GNU sort -V）
ver_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN{
    split(a, A, "."); split(b, B, ".")
    for (i = 1; i <= 3; i++) {
      x = A[i] + 0; y = B[i] + 0
      if (x > y) exit 0
      if (x < y) exit 1
    }
    exit 0
  }'
}

# pkg-config 当前能找到的 SDL3 dylib 路径
sdl3_dylib() {
  local libdir
  libdir=$(pkg-config --variable=libdir sdl3 2>/dev/null) || return 1
  [ -n "$libdir" ] || return 1
  ls "$libdir"/libSDL3*.dylib 2>/dev/null | head -1
}

# dylib 的最低系统版本要求（LC_BUILD_VERSION 的 minos）
sdl3_minos() {
  local dylib=$1
  [ -f "$dylib" ] || return 1
  otool -l "$dylib" 2>/dev/null | awk '
    /LC_BUILD_VERSION/      { mode = 1 }
    /LC_VERSION_MIN_MACOSX/ { mode = 2 }
    mode == 1 && $1 == "minos"   { print $2; exit }
    mode == 2 && $1 == "version" { print $2; exit }
  '
}

# 从源码编译 SDL3 装到 $SDL3_PREFIX，再用 PKG_CONFIG_PATH 喂给 scrcpy 的 meson
build_sdl3_source() {
  local tag ver pack url src build dylib

  command -v cmake >/dev/null 2>&1 || brew install cmake
  command -v ninja >/dev/null 2>&1 || brew install ninja

  ver=$SDL3_VERSION
  if [ -z "$ver" ]; then
    tag=$(get_github_release_version libsdl-org/SDL) # 形如 release-3.4.12
    ver=${tag#*-}
  fi
  case "$ver" in
    '' | *[!0-9.]*) ver=3.2.0 ;;
  esac
  echo "SDL3 source version is $ver"

  pack=SDL3-${ver}.tar.gz
  url=https://github.com/libsdl-org/SDL/releases/download/release-${ver}/${pack}
  $(cache_downloader "$pack" "$url")

  src=$(install_path)/SDL3-${ver}
  build=${src}-build
  rm -rf "$src" "$build" "$SDL3_PREFIX"
  mkdir -p "$src"
  tar -xzf "$(cache_folder)/${pack}" -C "$src" --strip-components=1

  cmake -S "$src" -B "$build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$SDL3_PREFIX" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_VER" \
    -DCMAKE_INSTALL_NAME_DIR="$SDL3_PREFIX/lib" \
    -DSDL_SHARED=ON -DSDL_STATIC=OFF \
    -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF -DSDL_INSTALL_TESTS=OFF
  cmake --build "$build"
  cmake --install "$build"

  # SDL 的 CMake 可能把 dylib 的 install_name 写成 @rpath/libSDL3.0.dylib，
  # 而 meson 不会替我们给 prefix 加 rpath，运行期就 dyld: library not loaded。
  # 这里强制改写为绝对路径（幂等），再补一条链接期 rpath 双保险。
  for dylib in "$SDL3_PREFIX"/lib/libSDL3*.dylib; do
    # 只改真实文件，符号链接（libSDL3.dylib -> libSDL3.0.dylib）跳过，
    # 保证 LC_ID_DYLIB 落在真正的 SONAME 上
    [ -f "$dylib" ] && [ ! -L "$dylib" ] && install_name_tool -id "$dylib" "$dylib"
  done

  export PKG_CONFIG_PATH="$SDL3_PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  export LDFLAGS="-L$SDL3_PREFIX/lib -Wl,-rpath,$SDL3_PREFIX/lib${LDFLAGS:+ $LDFLAGS}"
  # 之后的 shell / 其他软件也能复用这套 SDL3
  cat >"$(toolsRC sdl3rc)" <<EOF
export PKG_CONFIG_PATH=$SDL3_PREFIX/lib/pkgconfig:\${PKG_CONFIG_PATH:-}
EOF
}

# 保证 sdl3 >= 3.2.0 可用：优先 homebrew，旧系统自动回落源码编译
ensure_sdl3() {
  local dylib minos

  case "$SCRCPY_SDL3_MODE" in
    source)
      build_sdl3_source
      return $?
      ;;
    brew)
      brew install sdl3
      ;;
    auto)
      # macOS 12 及更旧：Homebrew 已不再提供可用的 sdl3 bottle，直接源码编译，
      # 省掉一次注定失败（或超慢的 from-source）尝试。
      if [ -n "$MACOS_MAJOR" ] && [ "$MACOS_MAJOR" -lt 13 ]; then
        echo "macOS $MACOS_VER 过旧，Homebrew 无可用 sdl3，直接源码编译 SDL3"
        build_sdl3_source
        return $?
      fi
      brew install sdl3 || echo "Homebrew 安装 sdl3 失败，改为源码编译"
      ;;
  esac

  if pkg-config --exists "sdl3 >= $SDL3_MIN_VERSION"; then
    dylib=$(sdl3_dylib)
    minos=$(sdl3_minos "$dylib")
    if [ -z "$minos" ] || ver_ge "$MACOS_VER" "$minos"; then
      echo "使用 SDL3: $dylib (minos ${minos:-unknown})"
      return 0
    fi
    echo "Homebrew 的 SDL3 要求 macOS >= $minos，当前是 $MACOS_VER，改为源码编译"
  else
    echo "pkg-config 找不到 sdl3 >= $SDL3_MIN_VERSION，改为源码编译"
  fi

  if [ "$SCRCPY_SDL3_MODE" = brew ]; then
    echo "错误：SCRCPY_SDL3_MODE=brew 但 SDL3 校验失败，请改用 source 或 auto" >&2
    exit 1
  fi
  build_sdl3_source
}

# uname Linux .bashrc uname Darwin MINGW64 .bash_profile
PLATFORM=$(platform)
if [[ $(platform) == *mac* ]]; then
  case $(arch) in
    amd64) SOFT_ARCH=x86_64 ;;
    aarch64) SOFT_ARCH=aarch64 ;;
    386) SOFT_ARCH=32 ;;
  esac
  if [[ $SOFT_VERSION == *3.0* ]]; then
    SOFT_FILE_NAME=${NAME}-${PLATFORM}-${SOFT_ARCH}-${SOFT_VERSION}
    #action 自动打包有问题，其实没有用 gzip 压缩，手动修改一下
    SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
    SOFT_FILE_PACK_TAR=${SOFT_FILE_NAME}.tar
    # init pwd
    cd $HOME

    SOFT_URL=https://github.com/Genymobile/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}
    #if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
    if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
      $(cache_downloader $SOFT_FILE_PACK_TAR $SOFT_URL)
      $(cache_unpacker $SOFT_FILE_PACK_TAR $SOFT_FILE_NAME)

      rm -rf ${SOFT_HOME} &&
        mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}
    fi
    #--------------new .toolsrc-----------------------
    export PATH=$PATH:${SOFT_HOME}/${SOFT_FILE_NAME}

    echo 'export PATH=$PATH:'${SOFT_HOME}/${SOFT_FILE_NAME} >${TOOLSRC}
  else
    #build
    # runtime dependencies
    # scrcpy 4.x 用 SDL3，不需要 sdl2
    brew install ffmpeg libusb

    # client build dependencies
    brew install pkg-config meson ninja

    # SDL3：旧版 macOS（如 12.4）的 Homebrew 没有可用 bottle，函数内部会源码编译
    ensure_sdl3
    # 让 scrcpy 本体按当前系统版本部署，避免与 ffmpeg/libusb 的 minos 冲突
    export MACOSX_DEPLOYMENT_TARGET=${MACOS_VER}

    cd $(install_path)
    if [ ! -d "${SOFT_HOME}/.git" ]; then
      git clone https://github.com/${AUTHOR}/${NAME} $SOFT_HOME
    fi
    cd $SOFT_HOME
    git pull
    git checkout $SOFT_VERSION
    #prebuilt server
    SOFT_URL=https://github.com/Genymobile/${NAME}/releases/download/${SOFT_VERSION}/${NAME}-server-${SOFT_VERSION}
    SOFT_FILE_NAME=${NAME}-server-${SOFT_VERSION}
    $(cache_downloader $SOFT_FILE_NAME $SOFT_URL)
    cp $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}/
    # Homebrew 的 libusb-1.0.pc 把 Cflags 写成 -I<prefix>/include/libusb-1.0，
    # 而 scrcpy 源码里是 #include <libusb-1.0/libusb.h>，差一级目录就找不到头文件。
    # 用 CFLAGS 补 -I<prefix>/include：meson 会在 configure 时把 CFLAGS 固化进构建配置，
    # 实测比 -Dc_args 可靠（-Dc_args 在 --reconfigure 时不会进入编译命令）。
    if command -v brew >/dev/null 2>&1; then
      LIBUSB_PREFIX=$(brew --prefix libusb 2>/dev/null)
      if [ -n "$LIBUSB_PREFIX" ] && [ -d "$LIBUSB_PREFIX/include" ]; then
        export CFLAGS="-I$LIBUSB_PREFIX/include${CFLAGS:+ $CFLAGS}"
      fi
    fi

    #build
    # 之前用 sudo ninja -Cx install 时，meson 可能以 root 重新生成过构建目录，
    # 留下一批 root 属主文件，导致当前用户 configure 失败
    # （PermissionError: .../x/meson-private/cmake_sdl3/CMakeCache.txt）。
    if [ -d x ] && [ -n "$(find x -user root -print -quit 2>/dev/null)" ]; then
      echo "发现 root 属主的构建产物，回收所有权：${SOFT_HOME}/x"
      run_as_admin "chown -R $(id -un) '${SOFT_HOME}/x'"
    fi
    # 构建目录可能残留上一次（sdl2 / 另一套 SDL3）的配置，必须重新 configure
    if [ -d x ]; then
      meson setup --reconfigure x --buildtype release --strip -Db_lto=true \
        -Dprebuilt_server=${SOFT_FILE_NAME} ||
        (echo "错误：重新 configure 失败，请删除 ${SOFT_HOME}/x 后重跑本脚本" >&2 && exit 1)
    else
      meson x --buildtype release --strip -Db_lto=true \
        -Dprebuilt_server=${SOFT_FILE_NAME}
    fi
    ninja -Cx
    #install
    # 不要用 sudo 安装：Homebrew 的 meson 默认 prefix 是 /opt/homebrew，它本来就归
    # 当前用户所有，直接写即可。sudo 反而会 (1) 让 meson 以 root 重新生成构建目录，
    # 留下 root 属主文件导致下次 configure PermissionError；(2) 把 share/scrcpy 变成
    # root 属主，下次安装就写不进去。只有历史遗留的 root 属主目录才提权回收，
    # 走系统认证弹窗（支持指纹），不用 sudo。
    PREFIX=$(meson_prefix)
    if ! ninja -Cx install; then
      echo "普通用户安装失败，回收 ${PREFIX} 下相关路径的所有权后重试" >&2
      run_as_admin "mkdir -p '${PREFIX}/share/${NAME}' '${PREFIX}/bin'; chown -R $(id -un) '${PREFIX}/share/${NAME}' 2>/dev/null; chown $(id -un) '${PREFIX}/bin/${NAME}' 2>/dev/null; true"
      ninja -Cx install
    fi
    #echo 'alias scrcpy="'${SOFT_HOME}/run ${SOFT_HOME}/x'"' >${TOOLSRC}
  fi
fi
if [[ $(platform) == *linux* ]]; then
  case $(arch) in
    amd64) SOFT_ARCH=x86_64 ;;
    aarch64) SOFT_ARCH=arm ;;
    386) SOFT_ARCH=32 ;;
  esac

  if [[ $SOFT_ARCH == *64* ]] && [[ "$(uname -a)" != *KYLINOS* ]] && [[ $test_command == "还是不要直接下载，全部编译" ]]; then
    SOFT_FILE_NAME=${NAME}-${PLATFORM}-${SOFT_ARCH}-${SOFT_VERSION}
    #action 自动打包有问题，其实没有用 gzip 压缩，手动修改一下
    SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
    SOFT_FILE_PACK_TAR=${SOFT_FILE_NAME}.tar
    # init pwd
    cd $HOME

    SOFT_URL=https://github.com/Genymobile/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}
    #if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
    if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
      $(cache_downloader $SOFT_FILE_PACK_TAR $SOFT_URL)
      $(cache_unpacker $SOFT_FILE_PACK_TAR $SOFT_FILE_NAME)

      rm -rf ${SOFT_HOME} &&
        mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}
    fi
    #--------------new .toolsrc-----------------------
    SOFT_ROOT=${SOFT_HOME}/${SOFT_FILE_NAME}
    #export PATH=$PATH:${SOFT_HOME}
    export PATH=$PATH:${SOFT_ROOT}

    echo 'export PATH=$PATH:'${SOFT_ROOT} >${TOOLSRC}
  else
    #deb apt# for Debian/Ubuntu
    #旧版本
    #sudo apt install -y ffmpeg libsdl2-2.0-0 adb wget gcc git pkg-config meson ninja-build ccache libsdl2-dev libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev libswresample-dev libusb-1.0-0 libusb-1.0-0-dev
    # for Debian/Ubuntu
    sudo apt install -y ffmpeg libsdl3-0 libusb-1.0-0 adb wget \
      gcc git pkg-config meson ninja-build libsdl3-dev \
      libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev \
      libswresample-dev libusb-1.0-0-dev libv4l-dev
    
    cd $(install_path)
    git clone https://github.com/${AUTHOR}/${NAME} $SOFT_HOME
    cd $SOFT_HOME
    git pull
    git checkout $SOFT_VERSION
    #prebuilt server
    SOFT_URL=https://github.com/Genymobile/${NAME}/releases/download/${SOFT_VERSION}/${NAME}-server-${SOFT_VERSION}
    SOFT_FILE_NAME=${NAME}-server-${SOFT_VERSION}
    $(cache_downloader $SOFT_FILE_NAME $SOFT_URL)
    cp $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}/
    #build
    meson x --buildtype release --strip -Db_lto=true \
      -Dprebuilt_server=${SOFT_FILE_NAME}
    ninja -Cx
    #install
    # Linux 上 prefix 一般是 /usr/local（root 属主），必须用 sudo，这是正常且正确的。
    # 只有 prefix 指向用户可写目录（如 ~/.local）时才免 sudo，避免无谓产生 root 属主文件。
    PREFIX=$(meson_prefix)
    if [ -w "$PREFIX" ]; then
      ninja -Cx install
    else
      sudo ninja -Cx install
    fi
    #echo 'alias scrcpy="'${SOFT_HOME}/run ${SOFT_HOME}/x'"' >${TOOLSRC}
    #uninstall
    #sudo ninja -Cx uninstall
  fi
fi
if [[ $(platform) == *win* ]]; then
  case $(arch) in
    amd64) SOFT_ARCH=64 ;;
    386) SOFT_ARCH=32 ;;
  esac

  SOFT_FILE_NAME=${NAME}-${PLATFORM}${SOFT_ARCH}-${SOFT_VERSION}
  SOFT_FILE_PACK=$(soft_file_pack $SOFT_FILE_NAME)
  # init pwd
  cd $HOME

  SOFT_URL=https://github.com/Genymobile/${NAME}/releases/download/${SOFT_VERSION}/${SOFT_FILE_PACK}
  #if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
  if [[ "$(${NAME} --version)" != *${NAME}\ ${SOFT_VERSION}* ]]; then
    $(cache_downloader $SOFT_FILE_PACK $SOFT_URL)
    $(cache_unpacker $SOFT_FILE_PACK $SOFT_FILE_NAME)

    rm -rf ${SOFT_HOME} &&
      mv $(cache_folder)/${SOFT_FILE_NAME} ${SOFT_HOME}
  fi
  #--------------new .toolsrc-----------------------
  export PATH=$PATH:${SOFT_HOME}

  echo 'export PATH=$PATH:'${SOFT_HOME} >${TOOLSRC}

  #  ----windows bat----
  if [[ $WIN_PATH ]]; then
    if [[ $PLATFORM == windows ]]; then
      windowsENV="$(echo -e ${PATH//:/;\\n}';' | sort | uniq | cygpath -w -f - | tr -d '\n')"
      echo $windowsENV
      setx Path "$windowsENV"
    fi
  fi
fi
