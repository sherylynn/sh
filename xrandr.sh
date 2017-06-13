xrandr
cvt 1920 1080
sudo xrandr --newmode "1920x1080_60.00"  173.00  1920 2048 2248 2576  1080 1083 1088 1120 -hsync +vsync
sudo xrandr --addmode DVI-0 "1920x1080_60.00"
sudo xrandr --output DVI-0 --mode "1920x1080_60.00"
