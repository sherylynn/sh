#!/bin/bash
. $(dirname "$0")/toolsinit.sh
SOFT_HOME=$(install_path)/Android/Sdk
LIBS_HOME=$(install_path)/Android/android-studio
TOOLSRC_NAME=androidrc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)
#--------------------------
#URL=
#--------------------------
#------load module---------
. ./winPath.sh
#--------------------------
export ANDROID_STUDIO_HOME=$LIBS_HOME
export ANDROID_ABI=arm64-v8a
export SDK_HOME=$SOFT_HOME

# ============================================================
# Android Studio ARM64 安装方案
# 基于 Rob Kean 的 Stack Overflow 回答 (2025-09)
# https://stackoverflow.com/a/79772235
# ============================================================

# --- 版本配置 ---
AS_VERSION="2025.1.3.7"
IDEA_VERSION="2025.2.2"
JBR_URL="https://cache-redirector.jetbrains.com/intellij-jbr/jbrsdk_ft-21.0.8-linux-aarch64-b1138.52.tar.gz"

AS_URL="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/${AS_VERSION}/android-studio-${AS_VERSION}-linux.tar.gz"
IDEA_URL="https://download.jetbrains.com/idea/ideaIC-${IDEA_VERSION}-aarch64.tar.gz"

# SDK / NDK 版本 (HomuHomu833 社区构建)
SDK_BUILD_TOOLS_35_URL="https://github.com/HomuHomu833/android-sdk-custom/releases/download/35.0.2/android-sdk-aarch64-linux-musl.tar.xz"
SDK_BUILD_TOOLS_36_URL="https://github.com/HomuHomu833/android-sdk-custom/releases/download/36.0.2/android-sdk-aarch64-linux-musl.tar.xz"
NDK_URL="https://github.com/HomuHomu833/android-ndk-custom/releases/download/r30/android-ndk-r30-beta1-aarch64-linux-musl.tar.xz"
NDK_DIRNAME="30.0.12642318"  # r30-beta1 对应的 NDK 版本号

# ============================================================
# Step 1: 下载并安装 Android Studio (排除 x86_64 原生组件)
# ============================================================
# 大文件下载函数 (支持断点续传)
download_large() {
  local dest="$(cache_folder)/$1"
  local url="$2"
  if [[ -f "$dest" ]]; then
    echo "  文件已存在，使用断点续传: $1"
    wget -c -O "$dest" "$url"
  else
    wget -O "$dest" "$url"
  fi
}

install_android_studio() {
  if [[ -d "${LIBS_HOME}/bin" ]]; then
    echo "[SKIP] Android Studio 已安装: ${LIBS_HOME}"
    return 0
  fi

  echo "[1/7] 下载 Android Studio ${AS_VERSION} (~1.1GB) ..."
  local AS_TAR="android-studio-${AS_VERSION}-linux.tar.gz"
  download_large "$AS_TAR" "$AS_URL"

  echo "[1/7] 解压 Android Studio (排除 x86_64 原生组件) ..."
  mkdir -p "$(dirname ${LIBS_HOME})"
  tar -xzf "$(cache_folder)/${AS_TAR}" \
    -C "$(dirname ${LIBS_HOME})" \
    --exclude 'android-studio/jbr/*' \
    --exclude 'android-studio/lib/jna/*' \
    --exclude 'android-studio/lib/native/*' \
    --exclude 'android-studio/lib/pty4j/*'

  echo "[1/7] Android Studio 基础文件安装完成"
}

# ============================================================
# Step 2: 从 IntelliJ IDEA 提取 ARM64 原生组件并覆盖
# ============================================================
overlay_arm64_natives() {
  echo "[2/7] 下载 IntelliJ IDEA Community ${IDEA_VERSION} (aarch64, ~700MB) ..."
  local IDEA_TAR="ideaIC-${IDEA_VERSION}-aarch64.tar.gz"
  download_large "$IDEA_TAR" "$IDEA_URL"

  echo "[2/7] 提取 ARM64 原生组件并覆盖 ..."
  tar -xzf "$(cache_folder)/${IDEA_TAR}" \
    -C "${LIBS_HOME}" \
    --wildcards '*/bin/fsnotifier' \
                '*/bin/restarter' \
                '*/lib/jna' \
                '*/lib/native' \
                '*/lib/pty4j' \
    --strip-components=1

  echo "[2/7] ARM64 原生组件覆盖完成"
}

# ============================================================
# Step 3: 安装 JetBrains Runtime (JBR) aarch64
# ============================================================
install_jbr() {
  if [[ -f "${LIBS_HOME}/jbr/bin/java" ]]; then
    local JBR_ARCH=$("${LIBS_HOME}/jbr/bin/java" -XshowSettings:property 2>&1 | grep "os.arch" | grep aarch64)
    if [[ -n "$JBR_ARCH" ]]; then
      echo "[SKIP] JBR aarch64 已安装"
      return 0
    fi
  fi

  echo "[3/7] 下载 JetBrains Runtime (JBR) aarch64 (~200MB) ..."
  local JBR_TAR="jbrsdk-aarch64.tar.gz"
  download_large "$JBR_TAR" "$JBR_URL"

  echo "[3/7] 安装 JBR ..."
  mkdir -p "${LIBS_HOME}/jbr"
  tar -xzf "$(cache_folder)/${JBR_TAR}" \
    -C "${LIBS_HOME}/jbr" \
    --strip-components=1

  echo "[3/7] JBR aarch64 安装完成"
}

# ============================================================
# Step 4: 修改配置文件，把 amd64 改成 aarch64
# ============================================================
patch_studio_config() {
  echo "[4/7] 修改 Android Studio 配置为 aarch64 ..."

  # 把 studio 二进制改名，防止误用 x86 版本
  if [[ -f "${LIBS_HOME}/bin/studio" ]]; then
    mv "${LIBS_HOME}/bin/studio" "${LIBS_HOME}/bin/studio.do_not_use"
    echo "  - 已重命名 bin/studio -> bin/studio.do_not_use"
  fi

  # 修改 shell 脚本里的 amd64 -> $OS_ARCH
  if [[ -d "${LIBS_HOME}/bin" ]]; then
    sed -i 's/amd64/$OS_ARCH/g' "${LIBS_HOME}/bin/"*.sh 2>/dev/null
    echo "  - 已修改 bin/*.sh 中的 amd64 -> \$OS_ARCH"
  fi

  # 修改 product-info.json 里的架构标识
  local PI_FILE=$(find "${LIBS_HOME}" -name "product-info.json" -maxdepth 2 2>/dev/null | head -1)
  if [[ -n "$PI_FILE" ]]; then
    sed -i 's/amd64/aarch64/g' "$PI_FILE"
    echo "  - 已修改 $(basename $PI_FILE) 中的 amd64 -> aarch64"
  fi

  echo "[4/7] 配置修改完成"
}

# ============================================================
# Step 5: 下载安装 ARM64 SDK 工具 (build-tools + platform-tools)
# ============================================================
install_sdk_tools() {
  if [[ -f "${SOFT_HOME}/build-tools/36.0.2/aapt2" ]]; then
    echo "[SKIP] SDK build-tools 36.0.2 已安装"
    return 0
  fi

  echo "[5/7] 下载 Android SDK build-tools 35.0.2 (aarch64, ~147MB) ..."
  local SDK35_TAR="android-sdk-35-aarch64.tar.xz"
  download_large "$SDK35_TAR" "$SDK_BUILD_TOOLS_35_URL"

  echo "[5/7] 安装 SDK build-tools 35.0.2 ..."
  mkdir -p "${SOFT_HOME}"
  # 先解压到临时目录再合并
  local TMP_SDK=$(cache_folder)/sdk35_tmp
  rm -rf "$TMP_SDK"
  mkdir -p "$TMP_SDK"
  tar -xf "$(cache_folder)/${SDK35_TAR}" -C "$TMP_SDK" --strip-components=1
  # 合并到 Sdk 目录
  cp -rn "$TMP_SDK"/* "${SOFT_HOME}/" 2>/dev/null || true
  cp -a "$TMP_SDK"/* "${SOFT_HOME}/" 2>/dev/null || true
  rm -rf "$TMP_SDK"

  echo "[5/7] 下载 Android SDK build-tools 36.0.2 (aarch64, ~149MB) ..."
  local SDK36_TAR="android-sdk-36-aarch64.tar.xz"
  download_large "$SDK36_TAR" "$SDK_BUILD_TOOLS_36_URL"

  echo "[5/7] 安装 SDK build-tools 36.0.2 ..."
  local TMP_SDK36=$(cache_folder)/sdk36_tmp
  rm -rf "$TMP_SDK36"
  mkdir -p "$TMP_SDK36"
  tar -xf "$(cache_folder)/${SDK36_TAR}" -C "$TMP_SDK36" --strip-components=1
  cp -rn "$TMP_SDK36"/* "${SOFT_HOME}/" 2>/dev/null || true
  cp -a "$TMP_SDK36"/* "${SOFT_HOME}/" 2>/dev/null || true
  rm -rf "$TMP_SDK36"

  echo "[5/7] SDK 工具安装完成"
}

# ============================================================
# Step 6: 下载安装 ARM64 NDK
# ============================================================
install_ndk() {
  if [[ -d "${SOFT_HOME}/ndk/${NDK_DIRNAME}" ]]; then
    echo "[SKIP] NDK ${NDK_DIRNAME} 已安装"
    return 0
  fi

  echo "[6/7] 下载 Android NDK (aarch64, ~170MB) ..."
  local NDK_TAR="android-ndk-aarch64.tar.xz"
  download_large "$NDK_TAR" "$NDK_URL"

  echo "[6/7] 安装 NDK ..."
  mkdir -p "${SOFT_HOME}/ndk"
  local TMP_NDK=$(cache_folder)/ndk_tmp
  rm -rf "$TMP_NDK"
  mkdir -p "$TMP_NDK"
  tar -xf "$(cache_folder)/${NDK_TAR}" -C "$TMP_NDK" --strip-components=1
  # NDK 解压出来的目录名类似 android-ndk-r30-beta1，重命名为版本号
  local NDK_SRC_DIR=$(ls -d "$TMP_NDK"/*/ 2>/dev/null | head -1)
  if [[ -n "$NDK_SRC_DIR" ]]; then
    mv "$NDK_SRC_DIR" "${SOFT_HOME}/ndk/${NDK_DIRNAME}"
  else
    # 如果没有子目录，直接当根目录用
    mv "$TMP_NDK" "${SOFT_HOME}/ndk/${NDK_DIRNAME}"
  fi
  rm -rf "$TMP_NDK"

  echo "[6/7] NDK 安装完成: ${SOFT_HOME}/ndk/${NDK_DIRNAME}"
}

# ============================================================
# Step 7: 配置 gradle.properties (aapt2 路径覆盖)
# ============================================================
setup_gradle_properties() {
  echo "[7/7] 配置 gradle.properties ..."

  local GRADLE_PROPS="${HOME}/.gradle/gradle.properties"
  local AAPT2_LINE="android.aapt2FromMavenOverride=${SOFT_HOME}/build-tools/36.0.2/aapt2"

  mkdir -p "$(dirname $GRADLE_PROPS)"

  if [[ -f "$GRADLE_PROPS" ]] && grep -q "android.aapt2FromMavenOverride" "$GRADLE_PROPS"; then
    # 已存在则更新
    sed -i "s|android.aapt2FromMavenOverride=.*|${AAPT2_LINE}|" "$GRADLE_PROPS"
    echo "  - 已更新 gradle.properties 中的 aapt2 路径"
  else
    # 不存在则追加
    echo "" >> "$GRADLE_PROPS"
    echo "# Android Studio ARM64: 强制使用本地 aapt2" >> "$GRADLE_PROPS"
    echo "${AAPT2_LINE}" >> "$GRADLE_PROPS"
    echo "  - 已添加 aapt2 覆盖配置到 gradle.properties"
  fi

  echo "[7/7] gradle.properties 配置完成"
}

# ============================================================
# 主流程
# ============================================================
if [[ $(platform) == *linux* ]] && [[ $(arch) == aarch64 ]]; then
  echo "============================================"
  echo "  Android Studio ARM64 安装脚本"
  echo "  基于 Stack Overflow 方案 by Rob Kean"
  echo "============================================"
  echo ""

  install_android_studio
  overlay_arm64_natives
  install_jbr
  patch_studio_config
  install_sdk_tools
  install_ndk
  setup_gradle_properties

  echo ""
  echo "============================================"
  echo "  安装完成!"
  echo "============================================"
  echo ""
  echo "启动方式:"
  echo "  ${LIBS_HOME}/bin/studio.sh"
  echo ""
  echo "首次启动后建议:"
  echo "  1. Settings -> Build -> Build Tools -> Project Sync mode: Manual Sync"
  echo "  2. Settings -> Languages & Frameworks -> Android SDK:"
  echo "     - SDK Platforms: 选择目标版本"
  echo "     - SDK Tools: 确认 Build-Tools, NDK, Platform-Tools 已勾选"
  echo "  3. 如果桌面入口需要指定 JAVA_HOME，编辑 .desktop 文件:"
  echo "     Exec=env JAVA_HOME=${LIBS_HOME}/jbr ${LIBS_HOME}/bin/studio.sh %f"
  echo ""
  echo "验证 ARM64 二进制:"
  echo "  file ${SOFT_HOME}/platform-tools/adb"
  echo "  file ${SOFT_HOME}/build-tools/36.0.2/aapt2"
  echo ""

  # --- QEMU KVM (用于模拟器, 可选) ---
  # 如果需要在 ARM64 上跑 x86 模拟器，取消下面的注释
  # sudo apt-get install qemu-kvm libvirt-clients libvirt-daemon-system -y

elif [[ $(platform) == *macos* ]]; then
  # macOS 保持原有的简单配置
  BREW_JAVA17_HOME="/opt/homebrew/opt/openjdk@17"
  if [[ -d "$BREW_JAVA17_HOME" ]]; then
    export JAVA_HOME=$BREW_JAVA17_HOME
  fi
  tee $TOOLSRC <<EOF
export JAVA_HOME=$JAVA_HOME
export ANDROID_HOME=$SOFT_HOME
EOF
else
  echo "[INFO] 非 ARM64 Linux 环境，仅写入环境变量配置"
fi

# --- 写入环境变量 (所有平台通用) ---
if [[ $(platform) != *macos* ]]; then
  tee $TOOLSRC <<EOF
export ANDROID_STUDIO_HOME=$LIBS_HOME
export SDK_HOME=$SOFT_HOME
export ANDROID_HOME=$SOFT_HOME
export ANDROID_ABI=$ANDROID_ABI
export ANDROID_SDK_ROOT=$SOFT_HOME
export ANDROID_SDK=$SOFT_HOME
export ANDROID_NDK=$SDK_HOME/ndk
export JAVA_HOME=$LIBS_HOME/jbr
export PATH=\$PATH:$LIBS_HOME/gradle/gradle-4.10.1/bin:$LIBS_HOME/jbr/bin:$LIBS_HOME/bin:$SOFT_HOME/emulator:$SOFT_HOME/platform-tools:$SOFT_HOME/cmdline-tools/latest/bin:$SOFT_HOME/ndk
EOF
fi
