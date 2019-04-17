#!/bin/bash
#diskutil list|grep WIN_EFI
#disk_label=WIN_EFI
#diskutil list|grep $disk_label

mount_by_label(){
  local DISK_LABEL=$1
  local DISK_MESSAGE=$(diskutil list|grep $DISK_LABEL)
  echo "DISK_MESSAGE is" ${DISK_MESSAGE}
  local DISK_ID=${DISK_MESSAGE#*disk}
  local DISK_NUMBER=${DISK_ID%s*}
  echo $DISK_NUMBER
  local DISK=disk${DISK_NUMBER}
  #echo $(diskutil info disk${DISK_NUMBER}|grep UUID)
  diskutil unmountDisk ${DISK}
  sudo rm -rf ~/${DISK_LABEL}_ssd.vmdk
  sudo VBoxManage internalcommands createrawvmdk -filename ~/${DISK_LABEL}_ssd.vmdk -rawdisk /dev/${DISK}
  diskutil unmountDisk ${DISK}
}
#show_label WIN_EFI
