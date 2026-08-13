#!/usr/bin/env bash
set -Eeuo pipefail

# 为 root 用户适配官方 ChatGPT Linux 包。
# Chromium 在 root 下必须使用 --no-sandbox；普通用户不添加该参数。

readonly APP="/usr/lib/chatgpt/ChatGPT"
readonly PACKAGE_LAUNCHER="/usr/lib/chatgpt/codex-launcher"
readonly WRAPPER="/usr/local/bin/chatgpt"
readonly DESKTOP_DIR="/root/.local/share/applications"
readonly DESKTOP_FILE="${DESKTOP_DIR}/chatgpt.desktop"
readonly DOWNLOAD_DIR="/sdcard/Download"
readonly ASAR="/usr/lib/chatgpt/resources/app.asar"
readonly PATCH_BACKUP_DIR="/root/tools/chatgpt-patch-backups"
readonly STDIN_EFAULT_OLD='t.closeStdin?n.end(e,a):n.write(e,a)'
# 保持替换前后字节数一致，避免改变 ASAR 内部文件偏移。
readonly STDIN_EFAULT_PATCHED='t.closeStdin?n.end(a  ):n.write(e,a)'
readonly STDIN_EFAULT_UPSTREAM_FIXED='t.closeStdin?n.end(a):n.write(e,a)'

info() { printf '\n==> %s\n' "$*"; }

find_chatgpt_deb() {
  local candidate newest=""
  local -a candidates
  shopt -s nullglob nocaseglob
  candidates=("$DOWNLOAD_DIR"/*chatgpt*.deb)
  for candidate in "${candidates[@]}"; do
    if [[ -z "$newest" || "$candidate" -nt "$newest" ]]; then
      newest="$candidate"
    fi
  done
  printf '%s' "$newest"
}
chatgpt_install_healthy() {
  [[ -x "$APP" && -x "$PACKAGE_LAUNCHER" ]] || return 1
  dpkg-query -W -f='${Status}' chatgpt 2>/dev/null | grep -Fq 'install ok installed'
}


install_chatgpt_if_needed() {
  chatgpt_install_healthy && return 0

  local deb package_arch machine_arch
  local -a installer=()
  deb=$(find_chatgpt_deb)
  [[ -n "$deb" ]] || die "未找到官方 ChatGPT，请把 chatgpt_*.deb 放到 $DOWNLOAD_DIR"
  [[ "$(dpkg-deb -f "$deb" Package 2>/dev/null)" == "chatgpt" ]] || die "不是 chatgpt deb：$deb"

  package_arch=$(dpkg-deb -f "$deb" Architecture 2>/dev/null)
  machine_arch=$(dpkg --print-architecture)
  [[ "$package_arch" == "$machine_arch" ]] || die "架构不匹配：系统为 $machine_arch，deb 为 $package_arch"

  info "检测到 ChatGPT 未安装，使用：$deb"
  if ((EUID != 0)); then
    command -v sudo >/dev/null 2>&1 || die "安装 deb 需要 root 权限"
    installer=(sudo)
  fi

  if ! "${installer[@]}" dpkg -i "$deb"; then
    command -v apt-get >/dev/null 2>&1 || die "deb 安装失败，且系统没有 apt-get 可用于修复依赖"
    "${installer[@]}" apt-get install -f -y
  fi
  [[ -x "$APP" ]] || die "deb 安装完成，但仍找不到可执行文件：$APP"
}


count_fixed_pattern() {
  local pattern=$1 file=$2
  { LC_ALL=C grep -aFo -- "$pattern" "$file" || true; } | wc -l
}

apply_stdin_efault_patch() {
  [[ -f "$ASAR" ]] || { info "未找到 app.asar，跳过 stdin EFAULT 补丁：$ASAR"; return 0; }
  command -v perl >/dev/null 2>&1 || { info "缺少 perl，无法安全应用 stdin EFAULT 补丁，已跳过"; return 0; }

  local old_count patched_count fixed_count package_version backup temp
  old_count=$(count_fixed_pattern "$STDIN_EFAULT_OLD" "$ASAR")
  patched_count=$(count_fixed_pattern "$STDIN_EFAULT_PATCHED" "$ASAR")
  fixed_count=$(count_fixed_pattern "$STDIN_EFAULT_UPSTREAM_FIXED" "$ASAR")

  if ((old_count == 0)); then
    if ((fixed_count > 0)); then
      info "官方版本已修复 stdin EFAULT，跳过本地补丁"
    elif ((patched_count > 0)); then
      info "stdin EFAULT 补丁已经应用，无需重复修改"
    else
      info "当前官方代码与已知模式不匹配，安全跳过 stdin EFAULT 补丁"
    fi
    return 0
  fi

  if ((patched_count > 0 || fixed_count > 0)); then
    info "检测到 stdin EFAULT 代码处于混合状态，安全起见不修改 app.asar"
    return 0
  fi

  package_version=$(dpkg-query -W -f='${Version}' chatgpt 2>/dev/null || printf unknown)
  backup="$PATCH_BACKUP_DIR/app.asar.${package_version}.original"
  temp="${ASAR}.stdin-efault.tmp.$$"
  install -d -m 0755 "$PATCH_BACKUP_DIR"
  if [[ ! -f "$backup" ]]; then
    cp --reflink=auto --preserve=mode,timestamps "$ASAR" "$backup"
    info "已备份官方 app.asar：$backup"
  fi

  CHATGPT_PATCH_OLD="$STDIN_EFAULT_OLD" CHATGPT_PATCH_NEW="$STDIN_EFAULT_PATCHED" \
    perl -0pe 's/\Q$ENV{CHATGPT_PATCH_OLD}\E/$ENV{CHATGPT_PATCH_NEW}/g' "$ASAR" > "$temp"
  original_size=$(stat -c '%s' "$ASAR")
  temp_size=$(stat -c '%s' "$temp")
  if [[ "$temp_size" != "$original_size" ]]; then
    rm -f -- "$temp"
    die "stdin EFAULT 补丁改变了 ASAR 大小（$original_size -> $temp_size），原文件未被修改"
  fi
  chmod --reference="$ASAR" "$temp"
  chown --reference="$ASAR" "$temp"

  if (( $(count_fixed_pattern "$STDIN_EFAULT_OLD" "$temp") != 0 ||
        $(count_fixed_pattern "$STDIN_EFAULT_PATCHED" "$temp") != old_count )); then
    rm -f -- "$temp"
    die "stdin EFAULT 补丁结果校验失败，原 app.asar 未被修改"
  fi

  mv -f -- "$temp" "$ASAR"
  info "已应用 stdin EFAULT 补丁（修复 $old_count 处）；官方包更新后脚本会重新检测"
}

die() { printf '错误：%s\n' "$*" >&2; exit 1; }
install_chatgpt_if_needed
apply_stdin_efault_patch

# 安装函数会检查实际程序；不能只检查 chatgpt 命令，因为旧包装器可能仍存在。

install -d -m 0755 "$(dirname "$WRAPPER")" "$DESKTOP_DIR"

cat > "$WRAPPER" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

readonly APP="/usr/lib/chatgpt/ChatGPT"
if (( EUID == 0 )); then
  exec "$APP" --no-sandbox "$@"
fi
exec "$APP" "$@"
EOF
chmod 0755 "$WRAPPER"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=ChatGPT
Comment=ChatGPT by OpenAI
GenericName=AI assistant
Exec=$WRAPPER %U
Icon=chatgpt
Type=Application
StartupNotify=true
Categories=Utility;Development;
MimeType=x-scheme-handler/chatgpt;
EOF
chmod 0644 "$DESKTOP_FILE"

printf '已完成 root 适配。\n'
printf '官方程序：%s\n' "$APP"
printf '终端启动：%s\n' "$WRAPPER"
printf '桌面启动配置：%s\n' "$DESKTOP_FILE"
