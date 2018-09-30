sudo apt install xinit -y
#echo exec startx > $HOME/.bash_profile
#will be error in ssh login
# or

sudo apt install i3 suckless-tools -y
sudo apt install xfce4-terminal -y
# or 
#sudo apt install lxterminal -y

sudo apt install lightdm -y

#sudo apt install network-manager network-manager-gnome
#sed -i 's/false/true/g' /etc/NetworkManager.conf
#sudo systemctl enable network-manager
#sudo systemctl restart network-manager

#---------or wicd
sudo apt install wicd
