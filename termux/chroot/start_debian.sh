#!/data/data/com.termux/files/usr/bin/bash
#apatch busybox
busybox=/data/adb/ap/bin/busybox

#Path of DEBIAN rootfs
debian_folder_path="/data/data/com.termux/files/home/Desktop/chrootdebian"
DEBIANPATH=$debian_folder_path

msg()
{
    echo "$@"
}

is_ok()
{
    if [ $? -eq 0 ]; then
        if [ -n "$2" ]; then
            msg "$2"
        fi
        return 0
    else
        if [ -n "$1" ]; then
            msg "$1"
        fi
        return 1
    fi
}

multiarch_support()
{
    if [ -d "/proc/sys/fs/binfmt_misc" ]; then
        return 0
    else
        return 1
    fi
}

get_pids()
{
    local pid pidfile pids
    for pid in $*
    do
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

kill_pids()
{
    local pids=$(get_pids $*)
    if [ -n "${pids}" ]; then
        sudo kill -9 ${pids}
        return $?
    fi
    return 0
}

is_mounted()
{
    local mount_point="$1"
    [ -n "${mount_point}" ] || return 1
    if $(grep -q " ${mount_point%/} " /proc/mounts); then
        return 0
    else
        return 1
    fi
}

container_mounted()
{
    is_mounted "${CHROOT_DIR}"
}

mount_part()
{
    case "$1" in
    root)
        msg -n "/ ... "
        if ! is_mounted "${CHROOT_DIR}" ; then
            [ -d "${CHROOT_DIR}" ] || sudo mkdir -p "${CHROOT_DIR}"
            sudo $busybox mount -o remount,exec,suid,dev "${CHROOT_DIR}"
            is_ok "fail" "done" || return 1
        else
            msg "skip"
        fi
    ;;
    proc)
        msg -n "/proc ... "
        local target="${CHROOT_DIR}/proc"
        if ! is_mounted "${target}" ; then
            [ -d "${target}" ] || sudo mkdir -p "${target}"
            sudo $busybox mount -t proc proc "${target}"
            is_ok "fail" "done"
        else
            msg "skip"
        fi
    ;;
    sys)
        msg -n "/sys ... "
        local target="${CHROOT_DIR}/sys"
        if ! is_mounted "${target}" ; then
            [ -d "${target}" ] || sudo mkdir -p "${target}"
            sudo $busybox mount -t sysfs sys "${target}"
            is_ok "fail" "done"
        else
            msg "skip"
        fi
    ;;
    system)
        msg -n "/system ... "
        local target="${CHROOT_DIR}/system"
        if ! is_mounted "${target}" ; then
            [ -d "${target}" ] || sudo mkdir -p "${target}"
            sudo $busybox mount -o ro /system "${target}"
            is_ok "fail" "done"
        else
            msg "skip"
        fi
    ;;
    vendor)
        msg -n "/vendor ... "
        local target="${CHROOT_DIR}/vendor"
        if ! is_mounted "${target}" ; then
            [ -d "${target}" ] || sudo mkdir -p "${target}"
            sudo $busybox mount -o ro /vendor "${target}"
            is_ok "fail" "done"
        else
            msg "skip"
        fi
    ;;
    apex)
        msg -n "/apex ... "
        local target="${CHROOT_DIR}/apex"
        if ! is_mounted "${target}" ; then
            [ -d "${target}" ] || sudo mkdir -p "${target}"
            sudo $busybox mount -o ro /apex "${target}"
            is_ok "fail" "done"
        else
            msg "skip"
        fi
    ;;
    com.android.runtime)
        msg -n "/apex/com.android.runtime ... "
        local target="${CHROOT_DIR}/apex/com.android.runtime"
        if ! is_mounted "${target}" ; then
            [ -d "${target}" ] || sudo mkdir -p "${target}"
            sudo $busybox mount -o ro /apex/com.android.runtime "${target}"
            is_ok "fail" "done"
        else
            msg "skip"
        fi
    ;;
    dev)
        msg -n "/dev ... "
        local target="${CHROOT_DIR}/dev"
        if ! is_mounted "${target}" ; then
            [ -d "${target}" ] || sudo mkdir -p "${target}"
            sudo $busybox mount -o bind /dev "${target}"
            is_ok "fail" "done"
        else
            msg "skip"
        fi
    ;;
    shm)
        msg -n "/dev/shm ... "
        if ! is_mounted "/dev/shm" ; then
            [ -d "/dev/shm" ] || sudo mkdir -p /dev/shm
            sudo $busybox mount -o rw,nosuid,nodev,mode=1777 -t tmpfs tmpfs /dev/shm
        fi
        local target="${CHROOT_DIR}/dev/shm"
        if ! is_mounted "${target}" ; then
            sudo $busybox mount -o bind /dev/shm "${target}"
            is_ok "fail" "done"
        else
            msg "skip"
        fi
    ;;
    pts)
        msg -n "/dev/pts ... "
        if ! is_mounted "/dev/pts" ; then
            [ -d "/dev/pts" ] || sudo mkdir -p /dev/pts
            sudo $busybox mount -o rw,nosuid,noexec,gid=5,mode=620,ptmxmode=000 -t devpts devpts /dev/pts
        fi
        local target="${CHROOT_DIR}/dev/pts"
        if ! is_mounted "${target}" ; then
            sudo $busybox mount -o bind /dev/pts "${target}"
            is_ok "fail" "done"
        else
            msg "skip"
        fi
    ;;
    fd)
        if [ ! -e "/dev/fd" -o ! -e "/dev/stdin" -o ! -e "/dev/stdout" -o ! -e "/dev/stderr" ]; then
            msg -n "/dev/fd ... "
            [ -e "/dev/fd" ] || sudo ln -s /proc/self/fd /dev/
            [ -e "/dev/stdin" ] || sudo ln -s /proc/self/fd/0 /dev/stdin
            [ -e "/dev/stdout" ] || sudo ln -s /proc/self/fd/1 /dev/stdout
            [ -e "/dev/stderr" ] || sudo ln -s /proc/self/fd/2 /dev/stderr
            is_ok "fail" "done"
        fi
    ;;
    tty)
        if [ ! -e "/dev/tty0" ]; then
            msg -n "/dev/tty ... "
            sudo ln -s /dev/null /dev/tty0
            is_ok "fail" "done"
        fi
    ;;
    tun)
        if [ ! -e "/dev/net/tun" ]; then
            msg -n "/dev/net/tun ... "
            [ -d "/dev/net" ] || sudo mkdir -p /dev/net
            mknod /dev/net/tun c 10 200
            is_ok "fail" "done"
        fi
    ;;
    binfmt_misc)
        multiarch_support || return 0
        local binfmt_dir="/proc/sys/fs/binfmt_misc"
        if ! is_mounted "${binfmt_dir}" ; then
            msg -n "${binfmt_dir} ... "
            sudo $busybox mount -t binfmt_misc binfmt_misc "${binfmt_dir}"
            is_ok "fail" "done"
        fi
    ;;
    esac

    return 0
}

container_mount()
{
    if [ $# -eq 0 ]; then
        container_mount root proc sys system vendor apex com.android.runtime dev shm pts fd tty tun binfmt_misc
        return $?
    fi

    msg "Mounting the container: "
    local item
    for item in $*
    do
        mount_part ${item} || return 1
    done

    return 0
}

container_umount()
{
    container_mounted || { msg "The container is not mounted." ; return 0; }

    msg -n "Release resources ... "
    local is_release=0
    local lsof_full=$(lsof | awk '{print $1}' | grep -c '^lsof')
    if [ "${lsof_full}" -eq 0 ]; then
        local pids=$(lsof | grep "${CHROOT_DIR%/}" | awk '{print $1}' | uniq)
    else
        local pids=$(lsof | grep "${CHROOT_DIR%/}" | awk '{print $2}' | uniq)
    fi
    kill_pids ${pids}; is_ok "fail" "done"

    msg "Unmounting partitions: "
    local is_mnt=0
    local mask
    for mask in '.*' '*'
    do
        local parts=$(sudo cat /proc/mounts | awk '{print $2}' | grep "^${CHROOT_DIR%/}/${mask}$" | sort -r)
        local part
        for part in ${parts}
        do
            local part_name=$(echo ${part} | sed "s|^${CHROOT_DIR%/}/*|/|g")
            msg -n "${part_name} ... "
            for i in 1 2 3
            do
                sudo $busybox umount ${part} && break
                sleep 1
            done
            is_ok "fail" "done"
            is_mnt=1
        done
    done
    [ "${is_mnt}" -eq 1 ]; is_ok " ...nothing mounted"

    return 0
}

# Fix setuid issue
sudo $busybox mount -o remount,dev,suid /data

sudo $busybox mount --bind /dev $DEBIANPATH/dev
sudo $busybox mount --bind /sys $DEBIANPATH/sys
sudo $busybox mount --bind /proc $DEBIANPATH/proc
sudo $busybox mount -t devpts devpts $DEBIANPATH/dev/pts

# /dev/shm for Electron apps
sudo mkdir -p $DEBIANPATH/dev/shm
sudo $busybox mount -t tmpfs -o size=256M tmpfs $DEBIANPATH/dev/shm

# Mount sdcard
sudo mkdir -p $DEBIANPATH/sdcard
sudo $busybox mount --bind /sdcard $DEBIANPATH/sdcard

# chroot into DEBIAN
#sudo $busybox chroot $DEBIANPATH /bin/su - root
#sudo $busybox chroot $DEBIANPATH /bin/su - root -c 'export XDG_RUNTIME_DIR=${TMPDIR} && export PULSE_SERVER=tcp:127.0.0.1:4713 && sudo service dbus start && su - lynn -c "env DISPLAY=:0 startxfce4"'
#for fcitx5
sudo $busybox chroot $DEBIANPATH /bin/su - root -c 'export DISPLAY=:0 && export PULSE_SERVER=127.0.0.1 && \
export GTK_IM_MODULE="fcitx" && \
export QT_IM_MODULE="fcitx" && \
export XMODIFIERS="@im=fcitx" && \
#fcitx5 && \
dbus-launch --exit-with-session startxfce4'
