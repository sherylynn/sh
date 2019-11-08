#echo autologin-user=$(whoami) |sudo tee -a /etc/lightdm/lightdm.conf
sudo tee -a /usr/share/lightdm/lightdm.conf.d/01_debian.conf << EOF
[SeatDefaults]
autologin-user=$(whoami)
autologin-user-timeout=0
EOF
