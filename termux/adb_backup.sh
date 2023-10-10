adb shell "su -c 'dd bs=1m if=/dev/block/bootdevice/by-name/persist' |gzip -c" > persist.img.gz
#adb exec-out "su -c 'dd bs=1m if=/dev/block/bootdevice/by-name/persist' |gzip -c" > persist.img.gz
#adb exec-in "tar xpf - -C / 2>/dev/null" < userdatabkp.tar

adb forward tcp:33333 tcp:33333
#busybox nc -l -p 3030 -e busybox sh -c 'dd if=/dev/block/mmcblk0p26 bs=512K | gzip' 
adb shell "su -c 'dd bs=1m if=/dev/block/bootdevice/by-name/persist' | gzip |/data/local/tmp/busybox nc -l -p 33333"
#on windows
nc 127.0.0.1 33333 >persist.img.gz
