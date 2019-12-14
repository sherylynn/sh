# set name of macSSD EFI is MAC_EFI
EFI_DISK=$(diskutil list|grep MAC_EFI|awk '{print $6}')
mkdir -p ~/efi
sudo mount -t msdos /dev/$EFI_DISK ~/efi
