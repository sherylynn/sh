curl -s https://install.zerotier.com/ | sudo bash
sudo zerotier-cli join 446b538c9d8ca1d3
sudo zerotier-cli set 446b538c9d8ca1d3 allowGlobal=1
cd ~/tools
proxychains wget https://download-cdn.resilio.com/stable/linux-armhf/resilio-sync_armhf.tar.gz
