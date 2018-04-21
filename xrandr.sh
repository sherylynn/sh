xrandr
#cvt 1920 1080
#sudo xrandr --newmode "1920x1080_60.00"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
#sudo xrandr --addmode DVI-0 "1920x1080_60.00"
#sudo xrandr --output DVI-0 --mode "1920x1080_60.00"
cvt 1366 768
sudo xrandr --newmode "1366x768_60.00"  85.25  1366 1440 1576 1784  768 771 781 798 -hsync +vsync
sudo xrandr --addmode VGA-1 "1366x768_60.00"
sudo xrandr --output VGA-1 --mode "1366x768_60.00"
sudo xrandr --rmmode "1366x768_60.00"
