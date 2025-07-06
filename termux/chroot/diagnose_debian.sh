#!/data/data/com.termux/files/usr/bin/bash

# Debian环境诊断脚本
echo "======== Debian环境诊断 ========"
echo

PREFIX=/data/data/com.termux/files/usr
DEBIAN_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian"
DEBIAN_OLD_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian-oldstable"
CHROOT_DIR="/data/local/mnt"

echo "检查的Debian路径列表："
debian_paths=(
  "$DEBIAN_DIR"
  "$DEBIAN_OLD_DIR"
  "/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian"
)

for i in "${!debian_paths[@]}"; do
  echo "  [$((i+1))] ${debian_paths[$i]}"
done
echo

# 详细检查每个路径
for debian_path in "${debian_paths[@]}"; do
  echo "======== 检查路径: $debian_path ========"
  
  # 检查目录是否存在 (使用sudo提权)
  if sudo test -d "$debian_path"; then
    echo "✓ 目录存在"
    
    # 显示目录大小和权限
    sudo ls -la "$debian_path" 2>/dev/null | head -10
    echo "..."
    echo "目录总大小: $(sudo du -sh "$debian_path" 2>/dev/null | cut -f1)"
    echo
    
    # 检查关键文件
    key_files=(
      "/bin/dpkg"
      "/bin/bash"
      "/bin/sh" 
      "/usr/bin/dpkg"
      "/etc/debian_version"
      "/var/lib/dpkg/status"
    )
    
    echo "关键文件检查："
    for file in "${key_files[@]}"; do
      full_path="${debian_path}${file}"
      if sudo test -f "$full_path"; then
        echo "  ✓ $file - 存在"
      elif sudo test -e "$full_path"; then
        echo "  ⚠ $file - 存在但不是普通文件 (类型: $(sudo file "$full_path" 2>/dev/null | cut -d: -f2))"
      else
        echo "  ✗ $file - 不存在"
      fi
    done
    echo
    
    # 检查bin目录内容
    echo "bin目录内容 (前10个)："
    if sudo test -d "${debian_path}/bin"; then
      sudo ls -la "${debian_path}/bin" 2>/dev/null | head -10
    else
      echo "  bin目录不存在"
    fi
    echo
    
    # 检查usr/bin目录内容  
    echo "usr/bin目录内容 (dpkg相关)："
    if sudo test -d "${debian_path}/usr/bin"; then
      sudo ls -la "${debian_path}/usr/bin" 2>/dev/null | grep dpkg
    else
      echo "  usr/bin目录不存在"
    fi
    echo
    
  else
    echo "✗ 目录不存在"
  fi
  echo "----------------------------------------"
  echo
done

# 检查proot-distro状态
echo "======== proot-distro状态 ========"
if command -v proot-distro >/dev/null 2>&1; then
  echo "✓ proot-distro命令可用"
  echo
  echo "已安装的发行版："
  proot-distro list --installed 2>/dev/null || echo "无法获取安装列表"
  echo
else
  echo "✗ proot-distro命令不可用"
fi

# 检查挂载点状态
echo "======== 挂载点状态 ========"
echo "当前chroot挂载点: $CHROOT_DIR"
if sudo test -d "$CHROOT_DIR"; then
  echo "✓ 挂载点目录存在"
  sudo ls -la "$CHROOT_DIR" 2>/dev/null | head -5
else
  echo "✗ 挂载点目录不存在"
fi
echo

# 检查相关的挂载信息
echo "相关挂载信息："
grep -E "(proot|chroot|${CHROOT_DIR})" /proc/mounts 2>/dev/null || echo "无相关挂载"
echo

# 提供修复建议
echo "======== 修复建议 ========"
echo "根据以上诊断结果："
echo

echo "1. 如果debian目录存在但缺少关键文件，可能需要重新安装："
echo "   proot-distro install debian"
echo

echo "2. 如果所有检查都正常，可能是检测条件过于严格，可以修改cli.sh："
echo "   将dpkg检查改为更宽松的条件"
echo

echo "3. 如果是权限问题，确保有足够的权限访问："
echo "   ls -la /data/data/com.termux/files/usr/var/lib/proot-distro/"
echo

# 尝试运行原始的检测函数
echo "======== 原始检测函数测试 ========"
check_debian_installed_debug() {
  local debian_paths=(
    "$DEBIAN_DIR"
    "$DEBIAN_OLD_DIR"
    "/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian"
  )
  
  echo "开始检测..."
  for debian_path in "${debian_paths[@]}"; do
    echo "检测路径: $debian_path"
    
    if sudo test -d "$debian_path"; then
      echo "  目录存在: ✓"
      
      if sudo test -f "$debian_path/bin/dpkg"; then
        echo "  dpkg文件存在: ✓"
        echo "  检测成功！找到有效的Debian安装"
        return 0
      else
        echo "  dpkg文件存在: ✗ ($debian_path/bin/dpkg)"
        
        # 尝试其他位置的dpkg
        if sudo test -f "$debian_path/usr/bin/dpkg"; then
          echo "  备用dpkg位置存在: ✓ ($debian_path/usr/bin/dpkg)"
        else
          echo "  备用dpkg位置存在: ✗ ($debian_path/usr/bin/dpkg)"
        fi
      fi
    else
      echo "  目录存在: ✗"
    fi
    echo
  done
  
  echo "检测失败：未找到有效的Debian安装"
  return 1
}

check_debian_installed_debug

echo
echo "诊断完成！"
echo "请将以上输出发送给开发者以获得更准确的帮助。" 