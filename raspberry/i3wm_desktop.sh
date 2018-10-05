sudo apt install xinit -y
#echo exec startx > $HOME/.bash_profile
#will be error in ssh login
# or
#sudo apt install lightdm -y

sudo apt install i3 -y
#sudo apt install xfce4-terminal -y
# or 
#sudo apt install lxterminal -y

sudo apt install fcitx-rime -y


#---------or network-manager
sudo apt install network-manager-gnome
sudo sed -i 's/false/true/g' /etc/NetworkManager.conf
sudo systemctl enable network-manager
sudo systemctl restart network-manager

#---------or wicd
#sudo apt install wicd -y
#mkdir -p $HOME/.i3
#cat /etc/i3/config > $HOME/.i3/config
#vi $HOME/.i3/config -c "normal Gdd" -c ":%s/Mod1/Mod4/g" -c "wq!"
#echo "exec --no-startup-id wicd-gtk -t ">> $HOME/.i3/config
#echo 'export GTK_IM_MODULE=fcitx' > $HOME/.xinitrc
#echo 'export QT_IM_MODULE=fcitx' >> $HOME/.xinitrc
#echo 'export XMODIFIERS="@im=fcitx"' >> $HOME/.xinitrc
#echo 'exec i3' >> $HOME/.xinitrc

