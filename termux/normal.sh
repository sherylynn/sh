apt install vim-python htop curl wget ncdu coreutils openssh -y
apt install termux-tools -y
apt install termux-services -y
apt install libcap ttyd -y
apt install rinetd -y
./termux_service_htop.sh
./termux_service_rinetd.sh
cd ~
termux-setup-storage
