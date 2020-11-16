cd ~
sudo apt install build-essential -y
git clone https://github.com/onitake/gslx680-acpi.git
cd gslx680-acpi
sudo make
sudo make install
sudo depmod -a
cd ~
git clone https://github.com/onitake/gsl-firmware.git
cp SileadTouch.sys gsl-firmware/tools
cd gsl-firmware/tools
./scanwindrv SileadTouch.sys
## ./fwtool -c firmware_00.fw -m 1680 -w 1730 -h 1120 -t 5 -f yflip  silead_ts.fw
./fwtool -c firmware_00.fw -m 1680 -w 1710 -h 1120 -t 5 -f yflip  silead_ts.fw
sudo cp silead_ts.fw /lib/firmware
sudo rmmod silead
sudo modprobe gslx_680_acpi
