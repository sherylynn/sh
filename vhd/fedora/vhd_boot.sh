cd ~
wget https://github.com/sherylynn/sh/releases/download/ntfs-3g/ntfs-3g_ntfsprogs-2017.3.23-fixed.zip
unzip ntfs-3g_ntfsprogs-2017*
#first time to see "too many args error"
#cd ~/ntfs*
cd ~/ntfs-3g_ntfsprogs-2017.3.23-fixed/ 
./configure
make
sudo make install

sudo dracut  -i ~/sh/vhd/fedora/10-vhdmount-kloop.sh /lib/dracut/hooks/pre-mount/10-vhdmount-kloop.sh  --no-hostonly  --install " vi /etc/virc ps grep cat rm blkid losetup  kpartx partx mount.fuse mount.ntfs-3g ntfs-3g shutdown  lvm  vgchange  vgmknodes  vgscan  dmsetup dmeventd  "   --add-drivers  "fuse dm-mod "  -o " plymouth btrfs crypt  cifs fcoe fcoe-uefi iscsi nfs nbd"  ~/dracut-fedora-kloop

#fedora not exist /vmlinuz in root dir
#sudo cp /vmlinuz ~/vmlinuz-fedora

