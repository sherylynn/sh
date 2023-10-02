if [[ -e ./images/super.img.zst ]]; then
	zstd --rm -d images/super.img.zst -o images/super.img
fi
echo "是否需要清除数据（y/n）"
read wipeData
fastboot set_active a
echo .开始刷入底层文件请稍等......
echo .
fastboot flash boot_a images/boot.img
fastboot flash bluetooth_a images/bluetooth.img
fastboot flash dsp_a images/dsp.img
fastboot flash dtbo_a images/dtbo.img
fastboot flash featenabler_a images/featenabler.img
fastboot flash modem_a images/modem.img
fastboot flash recovery_a images/recovery.img
fastboot flash vbmeta_system_a images/vbmeta_system.img
fastboot flash vbmeta_a images/vbmeta.img


if [[ -e images/preloader_raw.img ]]; then
	fastboot flash preloader_a images/preloader_raw.img 1>nul 2>nul
	fastboot flash preloader_b images/preloader_raw.img 1>nul 2>nul
	fastboot flash preloader1 images/preloader_raw.img 1>nul 2>nul
	fastboot flash preloader2 images/preloader_raw.img 1>nul 2>nul
fi
echo .
echo .
echo .如果显示 invalid sparse file format at header magic 为正常情况，不是报错
echo . 
echo .请耐心等待，线刷速度取决于电脑性能，也可以看下标题
echo .
echo .开始刷入系统镜像请稍等......
echo .
if [[ -e images/super.img ]]; then
  fastboot flash super images/super.img
fi
echo .
echo .
echo .刷完super可能会卡一段时间，请耐心等待，请勿自行重启，否则可能不开机需要重刷
echo .
echo .如果长时间没有反应，请尝试手动开机或者重刷一遍
echo .
echo .

if [[ -e $wipeData == "y" ]]; then
	fastboot erase userdata
	fastboot erase metadata
fi
fastboot set_active a
fastboot reboot
