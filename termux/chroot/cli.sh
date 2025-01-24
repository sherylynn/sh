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
  case "$1" in
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
  if [ $# -eq 0 ]; then
    #container_mount data dev sys proc pts shm sdcard tmp
    container_mount root dev sys proc pts shm sdcard tmp
    return $?
  fi

  echo "Mounting the container: "
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
  sudo rm -rf $DEBIAN_DIR/tmp/rime*
  sudo rm -rf $PREFIX/tmp/tigervnc*
  sudo rm -rf $DEBIAN_DIR/tmp/tigervnc*
  sudo rm -rf $PREFIX/tmp/ssh-*
  sudo rm -rf $DEBIAN_DIR/tmp/ssh-*
  sudo rm -rf $PREFIX/tmp/pulse-*
  sudo rm -rf $DEBIAN_DIR/tmp/pulse-*

  sudo rm -rf $DEBIAN_DIR/root/tigervnc*
  #sudo rm -rf $DEBIAN_DIR/etc/xrdp/km-*.ini
  #default /etc/xrdp/sesman.ini X11DisplayOffset=10
}
