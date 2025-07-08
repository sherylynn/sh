#!/data/data/com.termux/files/usr/bin/bash
#kernelsu busybox
sudo test -f /data/adb/ksu/bin/busybox && busybox=/data/adb/ksu/bin/busybox
#apatch busybox
sudo test -f /data/adb/ap/bin/busybox && busybox=/data/adb/ap/bin/busybox
#for run in native emacs
PREFIX=/data/data/com.termux/files/usr

#Path of DEBIAN rootfs
#DEBIAN_DIR="/data/data/com.termux/files/home/Desktop/chrootdebian"
#proot 地址
DEBIAN_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian"
DEBIAN_OLD_DIR="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian-oldstable"
#Path of chroot mount dir
CHROOT_DIR="/data/local/mnt"
TERMUX_DIR="/data/data/com.termux/files"

SDCARD_DIR="/sdcard"

# 挂载配置文件路径
MOUNT_CONFIG="$(dirname "${BASH_SOURCE[0]}")/mount_config.conf"

#user config
USER_NAME=root
INIT_LEVEL=3
[ -n "${INIT_USER}" ] || INIT_USER="root"
[ -n "${INIT_ASYNC}" ] || INIT_ASYNC="true"

# sysv初始化系统配置
# INIT_LEVEL: 默认运行级别 (3=多用户文本模式)
# INIT_USER: 执行初始化脚本的用户 (root)
# INIT_ASYNC: 是否异步启动服务 (true=并行启动，false=串行启动)

# 卸载超时配置
UMOUNT_TIMEOUT="${UMOUNT_TIMEOUT:-5}"         # 进程终止超时时间(秒)
UMOUNT_FORCE_MODE="${UMOUNT_FORCE_MODE:-false}"  # 快速强制模式

# 注意: VNC相关功能已移除，由用户的noVNC.sh通过sysv初始化系统管理
# 参考: win-git/server_configure.sh 和 win-git/init_d_noVNC.sh
is_ok() {
  if [ $? -eq 0 ]; then
    if [ -n "$2" ]; then
      echo "$2"
    fi
    return 0
  else
    if [ -n "$1" ]; then
      echo "$1"
    fi
    return 1
  fi
}

multiarch_support() {
  if [ -d "/proc/sys/fs/binfmt_misc" ]; then
    return 0
  else
    return 1
  fi
}

is_mounted() {
  local mount_point="$1"
  [ -n "${mount_point}" ] || return 1
  if $(grep -q " ${mount_point%/} " /proc/mounts); then
    return 0
  else
    return 1
  fi
}

get_pids() {
  local pid pidfile pids
  for pid in $*; do
    pidfile="${CHROOT_DIR}${pid}"
    if [ -e "${pidfile}" ]; then
      pid=$(cat "${pidfile}")
    fi
    if [ -e "/proc/${pid}" ]; then
      pids="${pids} ${pid}"
    fi
  done
  if [ -n "${pids}" ]; then
    echo ${pids}
    return 0
  else
    return 1
  fi
}

is_started() {
  get_pids $* >/dev/null
}

is_stopped() {
  is_started $*
  test $? -ne 0
}

kill_pids() {
  local pids=$(get_pids $*)
  if [ -n "${pids}" ]; then
    sudo kill -9 ${pids}
    return $?
  fi
  return 0
}

remove_files() {
  local item target
  for item in $*; do
    target="${CHROOT_DIR}${item}"
    if [ -e "${target}" ]; then
      sudo rm -f "${target}"
    fi
  done
  return 0
}

make_dirs() {
  local item target
  for item in $*; do
    target="${CHROOT_DIR}${item}"
    if [ -d "${target%/*}" -a ! -d "${target}" ]; then
      mkdir "${target}"
    fi
  done
  return 0
}

# 检查debian安装状态
check_debian_installed() {
  # 检查多个可能的debian安装位置
  local debian_paths=(
    "$DEBIAN_DIR"
    "$DEBIAN_OLD_DIR"
    "/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian"
  )
  
  local debug_info=""
  
  for debian_path in "${debian_paths[@]}"; do
    debug_info="${debug_info}检查路径: $debian_path\n"
    
    if sudo test -d "$debian_path"; then
      debug_info="${debug_info}  目录存在: ✓\n"
      
      # 更宽松的检查条件 - 检查多个可能的dpkg位置和其他关键文件
      local found_indicator=false
      
      # 检查dpkg (使用sudo提权检查)
      if sudo test -f "$debian_path/bin/dpkg"; then
        debug_info="${debug_info}  /bin/dpkg: ✓\n"
        found_indicator=true
      elif sudo test -f "$debian_path/usr/bin/dpkg"; then
        debug_info="${debug_info}  /usr/bin/dpkg: ✓\n"
        found_indicator=true
      else
        debug_info="${debug_info}  dpkg: ✗ (未找到在/bin或/usr/bin)\n"
      fi
      
      # 检查其他关键文件作为备用验证 (使用sudo提权检查)
      if [ ! "$found_indicator" = true ]; then
        if sudo test -f "$debian_path/etc/debian_version"; then
          debug_info="${debug_info}  /etc/debian_version: ✓ (备用验证)\n"
          found_indicator=true
        elif sudo test -d "$debian_path/var/lib/dpkg"; then
          debug_info="${debug_info}  /var/lib/dpkg: ✓ (备用验证)\n"
          found_indicator=true
        elif sudo test -f "$debian_path/bin/bash"; then
          debug_info="${debug_info}  /bin/bash: ✓ (最低要求)\n"
          found_indicator=true
        fi
      fi
      
      if [ "$found_indicator" = true ]; then
        # 找到有效的debian安装，更新DEBIAN_DIR
        DEBIAN_DIR="$debian_path"
        debug_info="${debug_info}  检测结果: 成功 ✓\n"
        echo -e "找到Debian安装: $DEBIAN_DIR\n$debug_info" >&2
        return 0
      else
        debug_info="${debug_info}  检测结果: 失败 ✗\n"
      fi
    else
      debug_info="${debug_info}  目录存在: ✗\n"
    fi
    debug_info="${debug_info}\n"
  done
  
  echo -e "未找到Debian安装！\n\n详细信息:\n$debug_info\n请先运行: proot-distro install debian\n或运行诊断脚本: bash ~/sh/termux/chroot/diagnose_debian.sh" >&2
  return 1
}

# 读取挂载配置文件
load_mount_config() {
  if [ ! -f "$MOUNT_CONFIG" ]; then
    echo "警告: 挂载配置文件不存在: $MOUNT_CONFIG" >&2
    return 1
  fi
  
  # 导出当前变量供配置文件使用
  export DEBIAN_DIR CHROOT_DIR PREFIX
  
  echo "加载挂载配置: $MOUNT_CONFIG" >&2
}

# 解析配置行
parse_mount_config_line() {
  local line="$1"
  
  # 跳过注释和空行
  case "$line" in
    \#*|'') return 1 ;;
  esac
  
  # 使用envsubst替换变量(如果可用)或使用eval
  if command -v envsubst >/dev/null 2>&1; then
    line=$(echo "$line" | envsubst)
  else
    line=$(eval echo "\"$line\"")
  fi
  
  # 解析格式: name:source:target:options:enabled
  IFS=':' read -r mount_name source_path target_path mount_options enabled <<< "$line"
  
  # 检查必要字段
  if [ -z "$mount_name" ] || [ -z "$source_path" ] || [ -z "$target_path" ]; then
    echo "配置行格式错误: $line" >&2
    return 1
  fi
  
  # 输出解析后的值
  echo "$mount_name" "$source_path" "$target_path" "$mount_options" "$enabled"
  return 0
}

# 根据配置文件挂载
mount_from_config() {
  local mount_name="$1"
  
  if [ ! -f "$MOUNT_CONFIG" ]; then
    echo "配置文件不存在，使用默认挂载方式" >&2
    return 1
  fi
  
  # 导出变量供配置文件使用
  export DEBIAN_DIR CHROOT_DIR PREFIX
  
  while IFS= read -r line; do
    local parsed
    if parsed=$(parse_mount_config_line "$line"); then
      read -r cfg_name source target options enabled <<< "$parsed"
      
      if [ "$cfg_name" = "$mount_name" ] && [ "$enabled" = "1" ]; then
        echo -n "$mount_name ($source -> $target) ... "
        
        # 检查是否已挂载
        if is_mounted "$target"; then
          echo "skip"
          return 0
        fi
        
        # 创建目标目录
        [ -d "$target" ] || sudo mkdir -p "$target"
        
        # 根据挂载选项决定挂载类型
        case "$options" in
          *tmpfs*)
            sudo $busybox mount -t tmpfs -o "$options" tmpfs "$target"
            ;;
          *sysfs*)
            sudo $busybox mount -t sysfs sysfs "$target"
            ;;
          *proc*)
            sudo $busybox mount -t proc proc "$target"
            ;;
          *bind*)
            sudo $busybox mount -o "$options" "$source" "$target"
            ;;
          *)
            sudo $busybox mount -o bind "$source" "$target"
            ;;
        esac
        
        is_ok "fail" "done" || return 1
        return 0
      fi
    fi
  done < "$MOUNT_CONFIG"
  
  echo "未找到挂载配置: $mount_name" >&2
  return 1
}

chroot_exec() {
  unset TMP TEMP TMPDIR LD_PRELOAD LD_DEBUG
  local path="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  if [ "$1" = "-u" ]; then
    local username="$2"
    shift 2
  fi
  if [ -n "${username}" ]; then
    if [ $# -gt 0 ]; then
      sudo $busybox chroot "${CHROOT_DIR}" /bin/su - ${username} -c "$*"
    else
      sudo $busybox chroot "${CHROOT_DIR}" /bin/su - ${username}
    fi
  else
    PATH="${path}" chroot "${CHROOT_DIR}" $*
  fi
}

container_mounted() {
  is_mounted "${CHROOT_DIR}"
}

mount_part() {
  local part="$1"
  
  # 优先尝试从配置文件挂载
  if mount_from_config "$part"; then
    return 0
  fi
  
  # 配置文件失败，使用默认方式
  echo "使用默认挂载方式: $part" >&2
  
  case "$part" in
    #data)
    #    echo -n "/data ... "
    #    sudo $busybox mount -o remount,dev,suid /data
    #    is_ok "fail" "done" || return 1
    #;;
    root)
      echo -n "/ ... "
      if ! is_mounted "${CHROOT_DIR}"; then
        [ -d "${CHROOT_DIR}" ] || mkdir -p "${CHROOT_DIR}"
        local mnt_opts
        [ -d "${DEBIAN_DIR}" ] && mnt_opts="bind" || mnt_opts="rw,relatime"
        sudo $busybox mount -o ${mnt_opts} "${DEBIAN_DIR}" "${CHROOT_DIR}" &&
          sudo $busybox mount -o remount,exec,suid,dev "${CHROOT_DIR}"
        is_ok "fail" "done" || return 1
      else
        echo "skip"
      fi
      ;;
    dev)
      echo -n "/dev ... "
      local target="${CHROOT_DIR}/dev"
      if ! is_mounted "${target}"; then
        [ -d "${target}" ] || sudo mkdir -p "${target}"
        sudo $busybox mount -o bind /dev "${target}"
        is_ok "fail" "done"
      else
        echo "skip"
      fi
      ;;
    sys)
      echo -n "/sys ... "
      local target="${CHROOT_DIR}/sys"
      if ! is_mounted "${target}"; then
        [ -d "${target}" ] || sudo mkdir -p "${target}"
        sudo $busybox mount -t sysfs sys "${target}"
        is_ok "fail" "done"
      else
        echo "skip"
      fi
      ;;
    proc)
      echo -n "/proc ... "
      local target="${CHROOT_DIR}/proc"
      if ! is_mounted "${target}"; then
        [ -d "${target}" ] || sudo mkdir -p "${target}"
        sudo $busybox mount -t proc proc "${target}"
        is_ok "fail" "done"
      else
        echo "skip"
      fi
      ;;
    pts)
      echo -n "/dev/pts ... "
      if ! is_mounted "/dev/pts"; then
        [ -d "/dev/pts" ] || sudo mkdir -p /dev/pts
        sudo $busybox mount -o rw,nosuid,noexec,gid=5,mode=620,ptmxmode=000 -t devpts devpts /dev/pts
      fi
      local target="${CHROOT_DIR}/dev/pts"
      if ! is_mounted "${target}"; then
        sudo $busybox mount -o bind /dev/pts "${target}"
        is_ok "fail" "done"
      else
        echo "skip"
      fi
      ;;
    shm)
      echo -n "/dev/shm ... "
      if ! is_mounted "/dev/shm"; then
        [ -d "/dev/shm" ] || sudo mkdir -p /dev/shm
        sudo $busybox mount -o rw,nosuid,nodev,mode=1777 -t tmpfs tmpfs /dev/shm
      fi
      local target="${CHROOT_DIR}/dev/shm"
      if ! is_mounted "${target}"; then
        sudo $busybox mount -o bind /dev/shm "${target}"
        is_ok "fail" "done"
      else
        echo "skip"
      fi
      ;;
    sdcard)
      echo -n "/sdcard... "
      local target="${CHROOT_DIR}/sdcard"
      if ! is_mounted "${target}"; then
        [ -d "${target}" ] || sudo mkdir -p "${target}"
        sudo $busybox mount -o bind /sdcard "${target}"
        is_ok "fail" "done"
      else
        echo "skip"
      fi
      ;;
    tmp)
      echo -n "/tmp... "
      local target="${CHROOT_DIR}/tmp"
      if ! is_mounted "${target}"; then
        [ -d "${target}" ] || sudo mkdir -p "${target}"
        sudo $busybox mount -o bind $PREFIX/tmp "${target}"
        is_ok "fail" "done"
      else
        echo "skip"
      fi
      ;;
  esac

  return 0
}

container_mount() {
  # 首先检查debian是否已安装
  if ! check_debian_installed; then
    return 1
  fi
  
  # 加载挂载配置
  load_mount_config
  
  if [ $# -eq 0 ]; then
    # 使用配置文件中启用的挂载点，如果配置文件不存在则使用默认
    if [ -f "$MOUNT_CONFIG" ]; then
      echo "从配置文件挂载容器: $MOUNT_CONFIG"
      local mount_names=()
      
      # 导出变量
      export DEBIAN_DIR CHROOT_DIR PREFIX
      
      # 读取所有启用的挂载点
      while IFS= read -r line; do
        local parsed
        if parsed=$(parse_mount_config_line "$line"); then
          read -r cfg_name source target options enabled <<< "$parsed"
          if [ "$enabled" = "1" ]; then
            mount_names+=("$cfg_name")
          fi
        fi
      done < "$MOUNT_CONFIG"
      
      # 按顺序挂载
      container_mount "${mount_names[@]}"
      return $?
    else
      echo "配置文件不存在，使用默认挂载顺序"
      container_mount root dev sys proc pts shm sdcard tmp
      return $?
    fi
  fi

  echo "挂载容器组件: "
  local item
  for item in $*; do
    mount_part ${item} || return 1
  done

  return 0
}

# 倒计时函数
countdown_with_interrupt() {
    local timeout="$1"
    local message="$2"
    local skip_message="${3:-按任意键跳过等待并立即强制杀死进程}"
    
    echo -e "\n${message}"
    echo -e "${skip_message}"
    
    for i in $(seq $timeout -1 1); do
        printf "\r倒计时: %d秒 (按任意键跳过)" "$i"
        
        # 检查是否有按键输入 (使用read超时)
        if read -t 1 -n 1 -s; then
            echo -e "\n⚡ 用户跳过等待，立即强制终止！"
            return 1  # 返回1表示用户选择跳过
        fi
    done
    
    echo -e "\n⏰ 倒计时结束，强制终止进程！"
    return 0  # 返回0表示正常超时
}



container_umount() {
  container_mounted || {
    echo "The container is not mounted."
    return 0
  }

  echo "🔄 开始卸载容器..."
  
  # 检查是否启用快速强制模式
  if [ "$UMOUNT_FORCE_MODE" = "true" ]; then
    echo "⚡ 快速强制模式：直接强制杀死所有进程并卸载"
    force_cleanup_chroot
    return $?
  fi
  
  echo "🔍 开始搜索占用进程 (优化调试模式)..."
  local search_start_time=$(date +%s.%N)
  local search_timeout="${UMOUNT_SEARCH_TIMEOUT:-5}"  # 默认5秒超时
  
    # 使用 fuser 查找进程
  echo "  🔍 使用 fuser 查找进程..."
  local fuser_start=$(date +%s.%N)
  if command -v fuser >/dev/null 2>&1; then
    echo "    ✓ fuser 命令可用，开始搜索..."
    local fuser_result=$(sudo fuser "${CHROOT_DIR}" 2>/dev/null)
    local fuser_end=$(date +%s.%N)
    local fuser_duration=$(echo "$fuser_end - $fuser_start" | bc -l 2>/dev/null || echo "0")
    echo "    ⏱️  fuser 耗时: ${fuser_duration}秒"
    
    if [ -n "$fuser_result" ]; then
      pids=$(echo "$fuser_result" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -u)
      method_used="fuser"
      # echo "    ✅ fuser 找到进程: $pids"  # 不再显示进程号
    else
      echo "    ℹ️  fuser 未找到进程"
    fi
  else
    echo "    ❌ fuser 命令不可用"
  fi
  
  # 计算总搜索时间
  local search_end_time=$(date +%s.%N)
  local total_search_duration=$(echo "$search_end_time - $search_start_time" | bc -l 2>/dev/null || echo "0")
  
  # 检查是否超时
  if (( $(echo "$total_search_duration > $search_timeout" | bc -l 2>/dev/null || echo "0") )); then
    echo "⚠️  搜索超时 (${total_search_duration}秒 > ${search_timeout}秒)"
  fi
  
  echo ""
  echo "📊 进程搜索统计:"
  echo "  ⏱️  总搜索耗时: ${total_search_duration}秒"
  echo "  ⏱️  超时设置: ${search_timeout}秒"
  echo "  🔍 使用的方法: ${method_used:-无}"
  # echo "  📋 找到的进程: ${pids:-无}"  # 不再显示进程号
  
  # 进程终止逻辑
  if [ -n "$pids" ]; then
    echo ""
    echo "🔥 使用 fuser -k 强制终止进程..."
    sudo fuser -k -KILL "${CHROOT_DIR}" 2>/dev/null || true
    echo "✅ 进程终止完成"
  else
    echo "ℹ️  无进程占用"
  fi

  echo ""
  echo "🗂️  开始卸载分区："
  local is_mnt=0
  local failed_mounts=""
  
  # 参考linuxdeploy: 获取挂载点，按深度排序
  local all_mounts=$(awk '$2 ~ "^'${CHROOT_DIR%/}'" {print $2}' /proc/mounts | sort -r)
  
  for mount_point in $all_mounts; do
    local part_name=$(echo ${mount_point} | sed "s|^${CHROOT_DIR%/}/*|/|g")
    echo -n "  📂 卸载 ${part_name} ... "
    
    # linuxdeploy风格: 直接尝试多种卸载方法
    if sudo $busybox umount "${mount_point}" 2>/dev/null || \
       sudo umount "${mount_point}" 2>/dev/null || \
       sudo $busybox umount -l "${mount_point}" 2>/dev/null || \
       sudo umount -l "${mount_point}" 2>/dev/null || \
       sudo $busybox umount -f "${mount_point}" 2>/dev/null || \
       sudo umount -f "${mount_point}" 2>/dev/null; then
      echo "✅ 完成"
    else
      echo "❌ 失败 (busy)"
      failed_mounts="$failed_mounts $mount_point"
    fi
    
    is_mnt=1
  done
  
  # 处理卸载结果
  if [ -n "$failed_mounts" ]; then
    echo ""
    echo "⚠️  以下挂载点卸载失败:"
    for mount in $failed_mounts; do
      echo "   $mount"
    done
    echo ""
    echo "💡 建议使用强制清理: cforce 或 force_cleanup_chroot"
    echo "   这会强制终止所有相关进程并卸载挂载点"
    return 1
  elif [ "${is_mnt}" -eq 1 ]; then
    echo ""
    echo "🎉 容器卸载完成！"
    return 0
  else
    echo ""
    echo "ℹ️  没有发现挂载点"
    return 0
  fi
}

before_mount_fun() {
  # Fix setuid issue
  sudo $busybox mount -o remount,dev,suid /data

  sudo $busybox mount --bind /dev $CHROOT_DIR/dev
  sudo $busybox mount --bind /sys $CHROOT_DIR/sys
  sudo $busybox mount --bind /proc $CHROOT_DIR/proc
  sudo $busybox mount -t devpts devpts $CHROOT_DIR/dev/pts

  # /dev/shm for Electron apps
  sudo mkdir -p $CHROOT_DIR/dev/shm
  sudo $busybox mount -t tmpfs -o size=256M tmpfs $CHROOT_DIR/dev/shm

  # Mount sdcard
  sudo mkdir -p $CHROOT_DIR/sdcard
  sudo $busybox mount --bind /sdcard $CHROOT_DIR/sdcard

  # Mount tmp
  sudo $busybox mount --bind $PREFIX/tmp $CHROOT_DIR/tmp
}

after_umount_fun() {
  sudo $busybox umount $CHROOT_DIR/dev/shm
  sudo $busybox umount $CHROOT_DIR/dev/pts
  sudo $busybox umount $CHROOT_DIR/dev
  sudo $busybox umount $CHROOT_DIR/proc
  sudo $busybox umount $CHROOT_DIR/sys
  sudo $busybox umount $CHROOT_DIR/sdcard
  sudo $busybox umount $CHROOT_DIR/tmp
}

config_dbus() {
  echo ":: Configuring dbus ... "
  make_dirs /run/dbus /var/run/dbus
  
  # 创建machine-id文件（如果不存在）
  if ! sudo test -f "${CHROOT_DIR}/etc/machine-id"; then
    echo "创建machine-id文件..."
    sudo touch "${CHROOT_DIR}/etc/machine-id" || {
      echo "警告: 无法创建machine-id文件，跳过..."
      return 0
    }
  fi
  
  # 生成machine-id
  echo "生成machine-id..."
  chroot_exec -u root dbus-uuidgen 2>/dev/null | sudo tee "${CHROOT_DIR}/etc/machine-id" >/dev/null || {
    echo "警告: 无法生成machine-id，使用默认值..."
    echo "$(cat /proc/sys/kernel/random/uuid | tr -d '-')" | sudo tee "${CHROOT_DIR}/etc/machine-id" >/dev/null || true
  }
  
  # 设置权限（使用sudo，失败不中断）
  echo "设置machine-id权限..."
  sudo chmod 644 "${CHROOT_DIR}/etc/machine-id" 2>/dev/null || {
    echo "警告: 无法设置machine-id权限，继续..."
  }
  
  return 0
}

start_dbus() {
  echo ":: Starting dbus ... "
  is_stopped /run/dbus/pid /run/dbus/messagebus.pid /run/messagebus.pid /var/run/dbus/pid /var/run/dbus/messagebus.pid /var/run/messagebus.pid
  is_ok "skip" || return 0
  remove_files /run/dbus/pid /run/dbus/messagebus.pid /run/messagebus.pid /var/run/dbus/pid /var/run/dbus/messagebus.pid /var/run/messagebus.pid
  chroot_exec -u root dbus-daemon --system --fork
  is_ok "fail" "done"
  return 0
}
#
stop_dbus() {
  echo ":: Stopping dbus ... "
  kill_pids /run/dbus/pid /run/dbus/messagebus.pid /run/messagebus.pid /var/run/dbus/pid /var/run/dbus/messagebus.pid /var/run/messagebus.pid
  is_ok "fail" "done"
  return 0
}



start_init() {
  container_mounted || {
    echo "The container is not mounted."
    return 0
  }
  [ -n "${INIT_LEVEL}" ] || return 0

  # 启动指定运行级别的服务 (默认级别3)
  local rc_dir="${CHROOT_DIR}/etc/rc${INIT_LEVEL}.d"
  local chroot_rc_dir="/etc/rc${INIT_LEVEL}.d"
  
  # 使用sudo检查目录是否存在
  if ! sudo test -d "$rc_dir"; then
    echo ":: Init level ${INIT_LEVEL} directory not found, skipping init services"
    return 0
  fi

  local services=$(sudo ls "$rc_dir/" 2>/dev/null | grep '^S' | sort)
  if [ -n "${services}" ]; then
    echo ":: Starting init (level ${INIT_LEVEL}): "
    local item
    for item in ${services}; do
      local service_name="${item/S[0-9][0-9]/}"
      echo -n "${service_name} ... "
      
      # 使用chroot内的路径执行服务脚本
      if [ "${INIT_ASYNC}" = "true" ]; then
        chroot_exec -u ${INIT_USER} "${chroot_rc_dir}/${item} start" 1>&2 &
      else
        chroot_exec -u ${INIT_USER} "${chroot_rc_dir}/${item} start" 1>&2
      fi
      is_ok "fail" "done"
    done
    
    # 如果是异步启动，等待一下让服务有时间启动
    if [ "${INIT_ASYNC}" = "true" ]; then
      echo ":: Waiting for async services to start..."
      sleep 3
    fi
  else
    echo ":: No init services found in level ${INIT_LEVEL}"
  fi

  return 0
}

stop_init() {
  container_mounted || {
    echo "The container is not mounted."
    return 0
  }
  [ -n "${INIT_LEVEL}" ] || return 0

  # 停止服务 (使用rc6.d，即关机级别)
  local rc_dir="${CHROOT_DIR}/etc/rc6.d"
  local chroot_rc_dir="/etc/rc6.d"
  
  # 使用sudo检查目录是否存在
  if ! sudo test -d "$rc_dir"; then
    echo ":: Shutdown directory not found, skipping init services"
    return 0
  fi

  local services=$(sudo ls "$rc_dir/" 2>/dev/null | grep '^K' | sort)
  if [ -n "${services}" ]; then
    echo ":: Stopping init: "
    local item
    for item in ${services}; do
      local service_name="${item/K[0-9][0-9]/}"
      echo -n "${service_name} ... "
      
      # 使用chroot内的路径执行服务脚本
      if [ "${INIT_ASYNC}" = "true" ]; then
        chroot_exec -u ${INIT_USER} "${chroot_rc_dir}/${item} stop" 1>&2 &
      else
        chroot_exec -u ${INIT_USER} "${chroot_rc_dir}/${item} stop" 1>&2
      fi
      is_ok "fail" "done"
    done
    
    # 如果是异步停止，等待一下让服务有时间停止
    if [ "${INIT_ASYNC}" = "true" ]; then
      echo ":: Waiting for async services to stop..."
      sleep 2
    fi
  else
    echo ":: No init services to stop"
  fi

  return 0
}

sdcard_link() {
  sdcard_rime=/sdcard/Download/rime
  sdcard_ssh=/sdcard/Download/.ssh
  sdcard_gitconfig=/sdcard/Download/.gitconfig
  sdcard_gitcredentials=/sdcard/Download/.git-credentials
  sudo rm -rf $DEBIAN_DIR/root/.gitconfig
  test -f $sdcard_gitconfig && sudo ln -s $sdcard_gitconfig $DEBIAN_DIR/root/.gitconfig
  sudo rm -rf $DEBIAN_DIR/root/.git-credentials
  test -f $sdcard_gitcredentials && sudo ln -s $sdcard_gitcredentials $DEBIAN_DIR/root/.git-credentials
  #复用输入法词库
  sudo rm -rf $DEBIAN_DIR/root/rime
  test -d $sdcard_rime && sudo ln -s $sdcard_rime $DEBIAN_DIR/root/rime
  #复用.ssh
  #权限问题只能拷贝.ssh
  #sudo rm -rf $DEBIAN_DIR/root/.ssh
  #test -d $sdcard_ssh && sudo cp -r $sdcard_ssh $DEBIAN_DIR/root/.ssh
  #sudo chmod 600 $DEBIAN_DIR/.ssh/config
  #sudo chown $USER $DEBIAN_DIR/.ssh/config
}
kill_need() {
  sudo killall emacs
  sudo killall emacs-*
}
clean_tmp() {
  sudo rm -rf $PREFIX/tmp/rime*
  sudo rm -rf $PREFIX/tmp/tigervnc*
  sudo rm -rf $PREFIX/tmp/ssh-*
  sudo rm -rf $PREFIX/tmp/pulse-*
  sudo rm -rf $PREFIX/tmp/dbus-*
  sudo rm -rf $PREFIX/tmp/vscode-*
  sudo rm -rf $PREFIX/tmp/Rtmp*
  sudo rm -rf $PREFIX/tmp/.X0-lock
  sudo rm -rf $PREFIX/tmp/.X10-lock

  sudo rm -rf $DEBIAN_DIR/tmp/rime*
  sudo rm -rf $DEBIAN_DIR/tmp/tigervnc*
  sudo rm -rf $DEBIAN_DIR/tmp/ssh-*
  sudo rm -rf $DEBIAN_DIR/tmp/pulse-*
  sudo rm -rf $DEBIAN_DIR/tmp/dbus-*
  sudo rm -rf $DEBIAN_DIR/tmp/vscode-*
  sudo rm -rf $DEBIAN_DIR/tmp/Rtmp*
  sudo rm -rf $DEBIAN_DIR/tmp/.X0-lock*
  sudo rm -rf $DEBIAN_DIR/tmp/.X10-lock*

  sudo rm -rf $DEBIAN_DIR/root/tigervnc*
  #sudo rm -rf $DEBIAN_DIR/etc/xrdp/km-*.ini
  #default /etc/xrdp/sesman.ini X11DisplayOffset=10
}

#===============================================================================
# 高级 Chroot 管理功能 (从 chroot_manager.sh 合并)
#===============================================================================

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 高级日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 高级chroot容器管理 - 启动
start_chroot_container() {
    log_info "启动chroot Linux容器..."
    
    # 检查是否已经挂载
    if container_mounted; then
        log_warn "容器已经在运行中"
        return 0
    fi
    
    # 检查环境安装状态
    if ! check_debian_installed; then
        return 1
    fi
    
    log_debug "开始挂载文件系统..."
    
    # 使用配置文件驱动的挂载系统
    if ! container_mount; then
        log_error "挂载失败"
        return 1
    fi
    
    # 配置网络
    log_debug "配置网络..."
    
    # 配置DNS解析器
    chroot_exec -u root bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf' 2>/dev/null || true
    chroot_exec -u root bash -c 'echo "nameserver 1.1.1.1" >> /etc/resolv.conf' 2>/dev/null || true
    
    # 强制重新创建 hosts 文件（防止空文件问题）
    log_debug "配置 hosts 文件..."
    chroot_exec -u root bash -c '
        cat > /etc/hosts << "EOF"
127.0.0.1   localhost localhost.localdomain
::1         localhost ip6-localhost ip6-loopback
127.0.1.1   $(hostname)
127.0.0.1   $(hostname)
EOF
        echo "hosts 文件已重新创建:"
        cat /etc/hosts
    ' 2>/dev/null || {
        log_warn "网络配置失败，使用备用方法..."
        # 备用方法：直接写入文件
        echo "127.0.0.1 localhost localhost.localdomain" | sudo tee "${CHROOT_DIR}/etc/hosts" >/dev/null
        echo "::1 localhost ip6-localhost ip6-loopback" | sudo tee -a "${CHROOT_DIR}/etc/hosts" >/dev/null
    }
    
    # 启动 sysv 初始化系统服务 (包括用户的noVNC等服务)
    log_debug "启动初始化系统服务 (级别 ${INIT_LEVEL})..."
    start_init
    
    # 设置环境变量
    export DISPLAY=:1
    export PULSE_RUNTIME_PATH=/run/user/$(id -u)/pulse
    
    log_info "Chroot Linux容器启动完成！(包括初始化系统服务)"
    return 0
}

# 强制清理挂载点 - 应急工具
force_cleanup_chroot() {
    log_warn "执行强制清理挂载点..."
    
    # 获取所有相关挂载点
    local all_mounts=$(sudo cat /proc/mounts | awk '{print $2}' | grep "^${CHROOT_DIR%/}" | sort -r)
    
    if [ -z "$all_mounts" ]; then
        log_info "没有发现相关挂载点"
        return 0
    fi
    
    log_warn "发现挂载点: $(echo $all_mounts | tr '\n' ' ')"
    
    # 强制终止所有相关进程
    log_debug "强制终止所有相关进程..."
    
    # 使用fuser强制终止(最可靠)
    if command -v fuser >/dev/null 2>&1; then
        local fuser_pids=$(sudo fuser -k -KILL "${CHROOT_DIR}" 2>/dev/null || true)
        # [ -n "$fuser_pids" ] && log_warn "fuser终止进程: $fuser_pids"  # 不再显示进程号
    fi
    
    # 补充lsof查找遗漏进程
    if command -v lsof >/dev/null 2>&1; then
        local lsof_pids=$(sudo lsof +D "${CHROOT_DIR}" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u)
        for pid in $lsof_pids; do
            [ -e "/proc/$pid" ] && sudo kill -KILL "$pid" 2>/dev/null
        done
        # [ -n "$lsof_pids" ] && log_warn "lsof终止进程: $lsof_pids"  # 不再显示进程号
    fi
    
    sleep 1
    
    # 强制卸载所有挂载点
    log_debug "强制卸载所有挂载点..."
    for mount_point in $all_mounts; do
        local part_name=$(echo ${mount_point} | sed "s|^${CHROOT_DIR%/}/*|/|g")
        echo -n "强制卸载 ${part_name} ... "
        
        # 强制卸载: lazy + force 组合
        sudo umount -f -l "${mount_point}" 2>/dev/null || \
        sudo $busybox umount -f -l "${mount_point}" 2>/dev/null || \
        true  # 确保不失败
        
        echo "done"
    done
    
    log_info "强制清理完成"
    return 0
}

# 高级chroot容器管理 - 停止
stop_chroot_container() {
    log_info "停止chroot Linux容器..."
    
    if ! container_mounted; then
        log_warn "容器未运行"
        return 0
    fi
    
    # 停止sysv初始化系统服务
    log_debug "停止初始化系统服务..."
    stop_init 2>/dev/null || true
    
    # 停止D-Bus服务
    log_debug "停止D-Bus服务..."
    stop_dbus 2>/dev/null || true
    
    # 使用现有的 container_umount 函数
    log_debug "卸载文件系统..."
    container_umount
    
    log_info "Chroot Linux容器已停止"
    return 0
}

# 检查chroot状态
check_chroot_status() {
    echo -e "${BLUE}=== Chroot Linux 状态 ===${NC}"
    
    # 检查debian安装
    if check_debian_installed 2>/dev/null; then
        echo -e "Debian安装: ${GREEN}已安装${NC} ($DEBIAN_DIR)"
    else
        echo -e "Debian安装: ${RED}未安装${NC}"
    fi
    
    # 检查挂载状态
    if container_mounted; then
        echo -e "容器状态: ${GREEN}已挂载${NC}"
    else
        echo -e "容器状态: ${RED}未挂载${NC}"
    fi
    
    # 检查sysv初始化系统
    if container_mounted && [ -n "${INIT_LEVEL}" ]; then
        local rc_dir="${CHROOT_DIR}/etc/rc${INIT_LEVEL}.d"
        if sudo test -d "$rc_dir"; then
            local services_count=$(sudo ls "$rc_dir/" 2>/dev/null | grep '^S' | wc -l)
            if [ "$services_count" -gt 0 ]; then
                echo -e "初始化系统: ${GREEN}级别${INIT_LEVEL} (${services_count}个服务)${NC}"
                echo -e "异步模式: ${BLUE}${INIT_ASYNC}${NC}"
            else
                echo -e "初始化系统: ${YELLOW}级别${INIT_LEVEL} (无服务)${NC}"
            fi
        else
            echo -e "初始化系统: ${RED}级别${INIT_LEVEL} (目录不存在)${NC}"
        fi
    else
        echo -e "初始化系统: ${RED}未配置${NC}"
    fi
    
    # 检查D-Bus服务
    if check_dbus_status; then
        echo -e "D-Bus服务: ${GREEN}运行中${NC}"
    else
        echo -e "D-Bus服务: ${RED}已停止${NC}"
    fi
    
    # 显示挂载点信息
    if container_mounted; then
        echo ""
        echo -e "${BLUE}挂载点信息:${NC}"
        mount | grep "$CHROOT_DIR" | while read -r line; do
            echo "  $line"
        done
    fi
    
    # 显示配置文件状态
    if [ -f "$MOUNT_CONFIG" ]; then
        echo -e "挂载配置: ${GREEN}已加载${NC} ($MOUNT_CONFIG)"
    else
        echo -e "挂载配置: ${YELLOW}使用默认${NC}"
    fi
}

# 进入chroot shell
enter_chroot_shell() {
    if ! container_mounted; then
        log_error "容器未运行，请先启动容器"
        echo "  使用: start_chroot_container 或 cstart"
        return 1
    fi
    
    log_info "进入chroot Linux环境..."
    chroot_exec -u root
}

# 在chroot中执行命令
exec_chroot_command() {
    local command="$*"
    
    if [ -z "$command" ]; then
        log_error "请提供要执行的命令"
        echo "  使用: exec_chroot_command <命令>"
        return 1
    fi
    
    if ! container_mounted; then
        log_error "容器未运行，请先启动容器"
        return 1
    fi
    
    log_info "在chroot中执行: $command"
    chroot_exec -u root bash -c "$command"
}

# 重启chroot容器
restart_chroot_container() {
    log_info "重启chroot Linux容器..."
    stop_chroot_container
    sleep 2
    start_chroot_container
}

# 命令行接口
chroot_manager_cli() {
    case "${1:-help}" in
        start|s)
            start_chroot_container
            ;;
        stop|st)
            stop_chroot_container
            ;;
        restart|r)
            restart_chroot_container
            ;;
        status|stat)
            check_chroot_status
            ;;
        shell|sh)
            enter_chroot_shell
            ;;
        exec|e)
            shift
            exec_chroot_command "$@"
            ;;
        mount|m)
            if ! container_mounted; then
                container_mount
            else
                echo "容器已挂载"
            fi
            ;;
        umount|u)
            if container_mounted; then
                container_umount
            else
                echo "容器未挂载"
            fi
            ;;
        fast-umount|fu)
            if container_mounted; then
                echo "🚀 启用快速强制卸载模式..."
                UMOUNT_FORCE_MODE=true container_umount
            else
                echo "容器未挂载"
            fi
            ;;
        set-timeout)
            local new_timeout="$2"
            if [[ "$new_timeout" =~ ^[0-9]+$ ]] && [ "$new_timeout" -gt 0 ] && [ "$new_timeout" -le 60 ]; then
                export UMOUNT_TIMEOUT="$new_timeout"
                echo "✅ 卸载超时时间已设置为: ${new_timeout}秒"
                echo "💡 这个设置只在当前会话有效，重启后恢复默认值"
            else
                echo "❌ 无效的超时时间: $new_timeout"
                echo "请输入1-60之间的数字"
            fi
            ;;
        force-cleanup|fc)
            log_warn "这是应急清理功能，只有在正常停止失败时使用！"
            read -p "确定要强制清理挂载点吗？(y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                force_cleanup_chroot
            else
                log_info "取消强制清理"
            fi
            ;;
        help|h|*)
            cat << EOF
${BLUE}Chroot Linux 管理命令${NC}

${GREEN}基础操作:${NC}
  ${YELLOW}start${NC}         - 启动chroot容器
  ${YELLOW}stop${NC}          - 停止chroot容器  
  ${YELLOW}restart${NC}       - 重启chroot容器
  ${YELLOW}status${NC}        - 查看容器状态

${GREEN}交互操作:${NC}
  ${YELLOW}shell${NC}         - 进入chroot shell
  ${YELLOW}exec${NC} <cmd>     - 在chroot中执行命令

${GREEN}挂载操作:${NC}
  ${YELLOW}mount${NC}         - 仅挂载文件系统
  ${YELLOW}umount${NC}        - 智能卸载 (倒计时+可跳过)
  ${YELLOW}fast-umount${NC}   - 快速强制卸载 (跳过所有等待)
  ${YELLOW}force-cleanup${NC} - 应急清理挂载点

${GREEN}配置选项:${NC}
  ${YELLOW}set-timeout${NC} <秒> - 设置卸载超时时间 (1-60秒)

${GREEN}卸载模式说明:${NC}
  🔹 ${YELLOW}umount${NC}        - 温和终止→倒计时等待→强制杀死 (用户可跳过)
  🔹 ${YELLOW}fast-umount${NC}   - 直接强制杀死所有进程并卸载 (最快)
  🔹 ${YELLOW}force-cleanup${NC} - 应急清理，当其他方法都失败时使用

${GREEN}环境变量:${NC}
  ${YELLOW}UMOUNT_TIMEOUT${NC}=${UMOUNT_TIMEOUT}      - 当前超时时间(秒)
  ${YELLOW}UMOUNT_FORCE_MODE${NC}=${UMOUNT_FORCE_MODE}  - 快速强制模式

${GREEN}常用示例:${NC}
  chroot_manager_cli start
  chroot_manager_cli shell
  chroot_manager_cli exec "apt update"
  chroot_manager_cli umount               # 智能卸载(推荐)
  chroot_manager_cli fast-umount          # 快速卸载
  chroot_manager_cli set-timeout 10       # 设置10秒超时
  chroot_manager_cli status

${GREEN}如果作为独立脚本运行:${NC}
  bash ~/sh/termux/chroot/cli.sh start
  bash ~/sh/termux/chroot/cli.sh fast-umount
EOF
            ;;
    esac
}

# 检查D-Bus服务
# 改进检测逻辑：既检查PID文件，也检查进程和服务状态
check_dbus_status() {
    # 方法1: 检查PID文件 (原有方式)
    if is_started /run/dbus/pid /run/dbus/messagebus.pid /run/messagebus.pid /var/run/dbus/pid /var/run/dbus/messagebus.pid /var/run/messagebus.pid >/dev/null 2>&1; then
        return 0  # 找到PID文件且进程存在
    fi
    
    # 方法2: 检查dbus进程是否在chroot中运行
    if container_mounted; then
        local dbus_processes=$(sudo chroot "$CHROOT_DIR" pgrep -f "dbus-daemon.*--system" 2>/dev/null || true)
        if [ -n "$dbus_processes" ]; then
            return 0  # 找到dbus进程
        fi
        
        # 方法3: 尝试连接D-Bus系统总线
        if sudo chroot "$CHROOT_DIR" dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.GetId >/dev/null 2>&1; then
            return 0  # D-Bus服务响应
        fi
    fi
    
    return 1  # 所有检查都失败
}

# 如果直接运行此脚本，则调用命令行接口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    chroot_manager_cli "$@"
fi
