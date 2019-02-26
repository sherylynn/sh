mkdir -p ~/efi
sudo mount -t msdos /dev/disk0s1 ~/efi
vim ~/efi/EFI/CLOVER/config.plist -c ':%s/macSSD/WIN_EFI/g' -c 'wq!'
sudo reboot
