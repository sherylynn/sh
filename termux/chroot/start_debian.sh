#!/data/data/com.termux/files/usr/bin/bash
#apatch busybox
busybox=/data/adb/ap/bin/busybox
#for run in native emacs
PREFIX=/data/data/com.termux/files/usr

#Path of DEBIAN rootfs
CHROOT_DIR="/data/data/com.termux/files/home/Desktop/chrootdebian"
#CHROOT_DIR="/data/local/tmp/chrootdebian"

is_ok()
{
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

multiarch_support()
{
    if [ -d "/proc/sys/fs/binfmt_misc" ]; then
        return 0
    else
        return 1
    fi
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
    is_mounted "${CHROOT_DIR}/tmp"
    #is_mounted "${CHROOT_DIR}"
}

mount_part()
{
    case "$1" in
    data)
        echo -n "/data ... "
        sudo $busybox mount -o remount,dev,suid /data
        is_ok "fail" "done" || return 1
    ;;
    dev)
        echo -n "/dev ... "
        local target="${CHROOT_DIR}/dev"
        if ! is_mounted "${target}" ; then
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
        if ! is_mounted "${target}" ; then
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
        if ! is_mounted "${target}" ; then
            [ -d "${target}" ] || sudo mkdir -p "${target}"
            sudo $busybox mount -t proc proc "${target}"
            is_ok "fail" "done"
        else
            echo "skip"
        fi
    ;;
    pts)
        echo -n "/dev/pts ... "
        if ! is_mounted "/dev/pts" ; then
            [ -d "/dev/pts" ] || sudo mkdir -p /dev/pts
            sudo $busybox mount -o rw,nosuid,noexec,gid=5,mode=620,ptmxmode=000 -t devpts devpts /dev/pts
        fi
        local target="${CHROOT_DIR}/dev/pts"
        if ! is_mounted "${target}" ; then
            sudo $busybox mount -o bind /dev/pts "${target}"
            is_ok "fail" "done"
        else
            echo "skip"
        fi
    ;;
    shm)
        echo -n "/dev/shm ... "
        if ! is_mounted "/dev/shm" ; then
            [ -d "/dev/shm" ] || sudo mkdir -p /dev/shm
            sudo $busybox mount -o rw,nosuid,nodev,mode=1777 -t tmpfs tmpfs /dev/shm
        fi
        local target="${CHROOT_DIR}/dev/shm"
        if ! is_mounted "${target}" ; then
            sudo $busybox mount -o bind /dev/shm "${target}"
            is_ok "fail" "done"
        else
            echo "skip"
        fi
    ;;
    sdcard)
        echo -n "/sdcard... "
        local target="${CHROOT_DIR}/sdcard"
        if ! is_mounted "${target}" ; then
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
        if ! is_mounted "${target}" ; then
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

container_mount()
{
    if [ $# -eq 0 ]; then
        container_mount data dev sys proc pts sdcard tmp
        return $?
    fi

    echo "Mounting the container: "
    local item
    for item in $*
    do
        mount_part ${item} || return 1
    done

    return 0
}

container_umount()
{
    container_mounted || { echo "The container is not mounted." ; return 0; }

    echo -n "Release resources ... "
    local is_release=0
    local pids=$(sudo $busybox lsof | grep "${CHROOT_DIR%/}" | awk '{print $1}' | uniq)
    #local pids=$(sudo $busybox lsof | grep "${CHROOT_DIR%/}" | awk '{print $2}' | uniq)
    echo ${pids}
    sudo kill ${pids}; is_ok "fail" "done"

    echo "Unmounting partitions: "
    local is_mnt=0
    local mask
    for mask in '.*' '*'
    do
        local parts=$(sudo cat /proc/mounts | awk '{print $2}' | grep "^${CHROOT_DIR%/}/${mask}$" | sort -r)
        local part
        for part in ${parts}
        do
            local part_name=$(echo ${part} | sed "s|^${CHROOT_DIR%/}/*|/|g")
            echo -n "${part_name} ... "
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

before_mount_fun()
{
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


after_umount_fun()
{
    sudo $busybox umount $CHROOT_DIR/dev/shm
    sudo $busybox umount $CHROOT_DIR/dev/pts
    sudo $busybox umount $CHROOT_DIR/dev
    sudo $busybox umount $CHROOT_DIR/proc
    sudo $busybox umount $CHROOT_DIR/sys
    sudo $busybox umount $CHROOT_DIR/sdcard
    sudo $busybox umount $CHROOT_DIR/tmp
}
