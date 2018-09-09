sudo zypper install gcc
cd ~
wget https://github.com/sherylynn/sh/releases/download/ntfs-3g/ntfs-3g_ntfsprogs-2017.3.23-fixed.zip
unzip ntfs-3g_ntfsprogs-2017*
#first time to see "too many args error"
#cd ~/ntfs*
cd ~/ntfs-3g_ntfsprogs-2017.3.23-fixed/ 
./configure
make
sudo make install

sudo rm -rf ~/dracut-opensuse-kloop

sudo dracut  -i ~/sh/vhd/opensuse/10-vhdmount-kloop.sh /lib/dracut/hooks/pre-mount/10-vhdmount-kloop.sh  --no-hostonly  --install " blkid kpartx  partx ntfs-3g fusermount  mount.fuse mount.ntfs-3g vgscan vgchange lvm  "   --add-drivers  "fuse loop  dm-mod "  -o " plymouth btrfs crypt  cifs dmraid mdraid multipath fcoe fcoe-uefi iscsi nfs nbd"   ~/dracut-opensuse-kloop

#fedora not exist /vmlinuz in root dir
#sudo cp /vmlinuz ~/vmlinuz-fedora

