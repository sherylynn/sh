#pacman -S networkmanager network-manager-applet
pacman -S networkmanager --needed --noconfirm 
systemctl enable NetworkManager
systemctl restart NetworkManager
#nmtui

#or
pacman -S wicd --needed --noconfirm
systemctl enable wicd
systemctl restart wicd
