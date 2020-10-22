apt install e2fsprogs -y
file_path=~/storage/downloads/deb_arm64.img
dd if=/dev/zero bs=1M count=1024 >> $file_path
e2fsck -f $file_path
resize2fs $file_path
