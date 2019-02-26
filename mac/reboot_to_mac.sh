mkdir -p ~/efi
sudo mount -t msdos /dev/disk0s1 ~/efi
vim ~/efi/EFI/CLOVER/config.plist -c ':%s/WIN_EFI/macSSD/g' -c 'wq!'
