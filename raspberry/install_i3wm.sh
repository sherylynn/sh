sudo apt install xinit -y
#echo exec startx > $HOME/.bash_profile
#will be error in ssh login
# or
#sudo apt install lightdm -y

sudo apt install i3 suckless-tools -y
sudo apt install xfce4-terminal -y
# or 
#sudo apt install lxterminal -y


#sudo apt install network-manager network-manager-gnome
#sed -i 's/false/true/g' /etc/NetworkManager.conf
#sudo systemctl enable network-manager
#sudo systemctl restart network-manager

#---------or wicd
sudo apt install wicd -y
sudo echo "exec --no-startup-id wicd-gtk -t "> $HOME/.i3/config
sudo echo 'export GTK_IM_MODULE=fcitx' > $HOME/.xinitrc
sudo echo 'export QT_IM_MODULE=fcitx' >> $HOME/.xinitrc
sudo echo 'export XMODIFIERS="@im=fcitx"' >> $HOME/.xinitrc
sudo echo 'exec i3' >> $HOME/.xinitrc

