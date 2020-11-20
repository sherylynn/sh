udevadm info /dev/iio:device0
#udevadm info -q path -n /dev/iio:device0
echo sensor:modalias:acpi:BOSC0200*: > 61-sensor-local.hwdb
cat /sys/class/dmi/id/modalias>> 61-sensor-local.hwdb
vim 61-sensor-local.hwdb -c "normal Jx" -c "x"
echo '*'>>61-sensor-local.hwdb
vim 61-sensor-local.hwdb -c "normal Jx" -c "x"
#cat /sys/`udevadm info -q path -n /dev/iio:device0`/../modalias

#echo ' ACCEL_MOUNT_MATRIX=0,0,0;0,0,0;0,0,0'>> 61-sensor-local.hwdb
#echo ' ACCEL_MOUNT_MATRIX=1,0,0;0,-1,0;0,0,1'>> 61-sensor-local.hwdb
echo ' ACCEL_MOUNT_MATRIX=0,-1,0;-1,0,0;0,0,1'>> 61-sensor-local.hwdb
sudo cp 61-sensor-local.hwdb /etc/udev/hwdb.d/61-sensor-local.hwdb
sudo systemd-hwdb update
udevadm trigger -v -p DEVNAME=/dev/iio:device0
