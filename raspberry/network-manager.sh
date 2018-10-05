sudo apt install network-manager-gnome -y
sudo systemctl enable network-manager
sudo systemctl start network-manager
sudo vi /etc/NetworkManager/NetworkManager.conf -c "%s/false/true/g" -c "wq!"
