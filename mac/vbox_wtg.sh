DISK_LABEL=WTG
DISK_MESSAGE=$(diskutil list|grep ${DISK_LABEL})
#from left to right first disk
DISK_ID=${DISK_MESSAGE#*disk}
#from right to left first s
DISK_NUMBER=${DISK_ID%s*}
echo $DISK_NUMBER
DISK=disk${DISK_NUMBER}
#echo $(diskutil info disk${DISK_NUMBER}|grep UUID)
diskutil unmountDisk ${DISK}
sudo rm -rf ~/wtg_usb_ssd.vmdk
sudo VBoxManage internalcommands createrawvmdk -filename ~/wtg_usb_ssd.vmdk -rawdisk /dev/${DISK}
diskutil unmountDisk ${DISK}
