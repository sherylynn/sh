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
VNC_DISPLAY=0
VNC_DEPTH=16
VNC_DPI=75
VNC_WIDTH=756
VNC_HEIGHT=1024
VNC_ARGS="--localhost no"
INIT_LEVEL=3
[ -n "${INIT_USER}" ] || INIT_USER="root"
#INIT_ASYNC="true"
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
  
  for debian_path in "${debian_paths[@]}"; do
    if [ -d "$debian_path" ] && [ -f "$debian_path/bin/dpkg" ]; then
      # 找到有效的debian安装，更新DEBIAN_DIR
      DEBIAN_DIR="$debian_path"
      echo "找到Debian安装: $DEBIAN_DIR" >&2
      return 0
    fi
  done
  
  echo "未找到Debian安装，请先运行: bash ~/sh/termux/chroot/installer_ruri.sh" >&2
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

container_umount() {
  container_mounted || {
    echo "The container is not mounted."
    return 0
  }

  echo -n "Release resources ... "
  local is_release=0
  local lsof_full=$(sudo $busybox lsof | awk '{print $1}' | grep -c '^lsof')
  if [ "${lsof_full}" -eq 0 ]; then
    local pids=$(sudo $busybox lsof | grep "${CHROOT_DIR%/}" | awk '{print $1}' | uniq)
  else
    local pids=$(sudo $busybox lsof | grep "${CHROOT_DIR%/}" | awk '{print $2}' | uniq)
  fi
  kill_pids ${pids}
  is_ok "fail" "done"

  #local pids=$(sudo $busybox lsof | grep "${CHROOT_DIR%/}" | awk '{print $1}' | uniq)
  #echo ${pids}
  #sudo kill ${pids}; is_ok "fail" "done"

  echo "Unmounting partitions: "
  local is_mnt=0
  local mask
  for mask in '.*' '*'; do
    local parts=$(sudo cat /proc/mounts | awk '{print $2}' | grep "^${CHROOT_DIR%/}/${mask}$" | sort -r)
    local part
    for part in ${parts}; do
      local part_name=$(echo ${part} | sed "s|^${CHROOT_DIR%/}/*|/|g")
      echo -n "${part_name} ... "
      for i in 1 2 3; do
        sudo $busybox umount ${part} && break
        sleep 1
      done
      is_ok "fail" "done"
      is_mnt=1
    done
  done
  [ "${is_mnt}" -eq 1 ]
  is_ok " ...nothing mounted"

  return 0
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
  echo ":: Configuring ${COMPONENT} ... "
  make_dirs /run/dbus /var/run/dbus
  chmod 644 "${CHROOT_DIR}/etc/machine-id"
  chroot_exec -u root dbus-uuidgen >"${CHROOT_DIR}/etc/machine-id"
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

start_vnc() {
  echo ":: Starting vnc ... "
  is_stopped /tmp/xsession.pid
  is_ok "skip" || return 0
  # remove locks
  remove_files "/tmp/.X${VNC_DISPLAY}-lock" "/tmp/.X11-unix/X${VNC_DISPLAY}"
  # exec vncserver
  chroot_exec -u ${USER_NAME} vncserver :${VNC_DISPLAY} -depth ${VNC_DEPTH} -dpi ${VNC_DPI} -geometry ${VNC_WIDTH}x${VNC_HEIGHT} ${VNC_ARGS}
  is_ok "fail" "done"
  return 0
}

stop_vnc() {
  container_mounted || {
    echo "The container is not mounted."
    return 0
  }
  echo ":: Stopping vnc ... "
  chroot_exec -u ${USER_NAME} vncserver -kill :${VNC_DISPLAY}
  kill_pids /tmp/xsession.pid
  is_ok "fail" "done"
  return 0
}

stop_init() {
  container_mounted || {
    echo "The container is not mounted."
    return 0
  }
  [ -n "${INIT_LEVEL}" ] || return 0

  local services=$(sudo ls "${CHROOT_DIR}/etc/rc6.d/" | grep '^K')
  if [ -n "${services}" ]; then
    echo ":: Stopping init: "
    local item
    for item in ${services}; do
      echo -n "${item/K[0-9][0-9]/} ... "
      if [ "${INIT_ASYNC}" = "true" ]; then
        chroot_exec -u ${INIT_USER} "/etc/rc6.d/${item} stop" 1>&2 &
      else
        chroot_exec -u ${INIT_USER} "/etc/rc6.d/${item} stop" 1>&2
      fi
      is_ok "fail" "done"
    done
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
    chroot_exec -u root bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf' 2>/dev/null || true
    chroot_exec -u root bash -c 'echo "127.0.0.1 localhost" > /etc/hosts' 2>/dev/null || true
    
    # 启动dbus服务
    log_debug "启动D-Bus服务..."
    config_dbus
    start_dbus
    
    # 设置环境变量
    export DISPLAY=:1
    export PULSE_RUNTIME_PATH=/run/user/$(id -u)/pulse
    
    log_info "Chroot Linux容器启动完成！"
    return 0
}

# 高级chroot容器管理 - 停止
stop_chroot_container() {
    log_info "停止chroot Linux容器..."
    
    if ! container_mounted; then
        log_warn "容器未运行"
        return 0
    fi
    
    # 停止服务
    log_debug "停止D-Bus服务..."
    stop_dbus 2>/dev/null || true
    
    log_debug "停止VNC服务..."
    stop_vnc 2>/dev/null || true
    
    log_debug "停止初始化服务..."
    stop_init 2>/dev/null || true
    
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
    
    # 检查D-Bus服务
    if is_started /run/dbus/pid /run/dbus/messagebus.pid /run/messagebus.pid /var/run/dbus/pid /var/run/dbus/messagebus.pid /var/run/messagebus.pid >/dev/null 2>&1; then
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
        help|h|*)
            cat << EOF
${BLUE}Chroot Linux 管理命令${NC}

${GREEN}基础操作:${NC}
  ${YELLOW}start${NC}     - 启动chroot容器
  ${YELLOW}stop${NC}      - 停止chroot容器  
  ${YELLOW}restart${NC}   - 重启chroot容器
  ${YELLOW}status${NC}    - 查看容器状态

${GREEN}交互操作:${NC}
  ${YELLOW}shell${NC}     - 进入chroot shell
  ${YELLOW}exec${NC} <cmd> - 在chroot中执行命令

${GREEN}挂载操作:${NC}
  ${YELLOW}mount${NC}     - 仅挂载文件系统
  ${YELLOW}umount${NC}    - 仅卸载文件系统

${GREEN}示例:${NC}
  chroot_manager_cli start
  chroot_manager_cli shell
  chroot_manager_cli exec "apt update"
  chroot_manager_cli status

${GREEN}如果作为独立脚本运行:${NC}
  bash ~/sh/termux/chroot/cli.sh start
EOF
            ;;
    esac
}

# 如果直接运行此脚本，则调用命令行接口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    chroot_manager_cli "$@"
fi
