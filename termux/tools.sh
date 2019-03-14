ln -s ~/storage/external-1 ~/tools
#sdcard的挂载方式是noexec，所以不能直接执行二进制
#operation not permitted
#go.sh not support
#node_all.sh not support
#要么把二进制放termux内，外挂放js或python这种解释性语言
#本想通过mount的方式挂载ext2
#结果发现没有root是执行不了/system/bin/mount的
#dd if=/dev/zero of=file.img bs=1M count=0 seek=2048#MB
#tar -czf file.img file.img.tar.gz
#tar -xzf file.img.tar.gz
#/system/bin/mount -o loop -t ext2 file.img dir
