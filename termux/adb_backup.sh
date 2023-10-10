adb shell "su -c 'dd bs=1m if=/dev/block/bootdevice/by-name/persist' |gzip -c" > persist.img.gz
