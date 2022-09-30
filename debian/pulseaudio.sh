sudo apt install pulseaudio -y
sudo rm -rf /etc/pulse/client.conf.d/00-disable-autospawn.conf
sudo cp ~/sh/debian/conf_pulseaudio/00-enable-autospawn.conf /etc/pulse/client.conf.d/
sudo cp ~/sh/debian/conf_pulseaudio/default.pa /etc/pulse/
sudo ~/sh/win-git/init_d_pulseaudio.sh
