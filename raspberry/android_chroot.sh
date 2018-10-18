sudo groupadd -g 3001 aid_net_bt_admin
sudo groupadd -g 3002 aid_net_bt
sudo groupadd -g 3003 aid_inet
sudo groupadd -g 3004 aid_inet_raw
sudo groupadd -g 3005 aid_inet_admin

sudo gpasswd -a $(whoami) aid_net_bt_admin
sudo gpasswd -a $(whoami) aid_net_bt
sudo gpasswd -a $(whoami) aid_inet
sudo gpasswd -a $(whoami) aid_inet_raw
sudo gpasswd -a $(whoami) aid_inet_admin

sudo usermod -g aid_inet _apt
sudo usermod -g aid_inet $(whoami)
