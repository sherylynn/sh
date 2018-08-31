sudo apt install kpartx util-linux dmsetup lvm2 -y
sudo apt install kpartx-boot -y
sudo apt install gcc g++ build-essential -y
sudo apt install wget unzip -y
sudo cp /usr/share/initramfs-tools/init ./init.bak
sudo vi /usr/share/initramfs-tools/init -c '/mount -t tmpfs -o \"noexec' -c 'normal ddk' -c 'read ./init' -c 'wq!'
sudo cp /usr/share/initramfs-tools/scripts/local ./local.bak
#需要判断是否已经执行过，可以通过搜索是否存在niumao，以免多次载入
if
  grep -q "niumao" /usr/share/initramfs-tools/scripts/local
then
  echo "local已经打过patch"
else
  sudo vi /usr/share/initramfs-tools/scripts/local -c '/fi\n\n\_slocal_premount' -c 'normal 2j' -c 'read ./local_1' -c '/fi\n}' -c 'read ./local_2' -c 'wq!'
  echo "patched local"
fi
if
  grep -q "util-linux" /usr/sbin/mkinitramfs
then
  echo "mkinitramfs had patched"
else
  sudo cp /usr/sbin/mkinitramfs ~/mkinitramfs.backup
  sudo vi /usr/sbin/mkinitramfs -c '/workaround' -c 'normal k' -c 'read ./mkinitramfs' -c 'wq!'
  echo "patched mkinitramfs"
fi
if
  grep -q "loop" /etc/initramfs-tools/modules
then
  echo "modules had patched"
else
  sudo cp /etc/initramfs-tools/modules ~/modules.backup
  sudo vi /etc/initramfs-tools/modules -c 'normal G' -c 'read ./modules' -c 'wq!'
  echo "patched modules"
fi

cd ~
wget https://github.com/sherylynn/sh/releases/download/ntfs-3g/ntfs-3g_ntfsprogs-2017.3.23-fixed.zip
unzip ntfs-3g_ntfsprogs-2017*
cd ~/ntfs*
./configure
make
sudo make install

cd ~/sh/vhd/ubuntu
sudo cp /usr/share/initramfs-tools/scripts/local-bottom/ntfs_3g ~/ntfs_3g.backup
sudo vi /usr/share/initramfs-tools/scripts/local-bottom/ntfs_3g  -c 'normal dd=G' -c 'read ./ntfs_3g' -c 'wq!'
