#!/bin/bash
sudo apt install aria2 -y
#FRP_ARCH=arm

if [ ! -d "/etc/aria2c" ]; then
sudo mkdir /etc/aria2c
sudo cp $HOME/aria2-linux.conf /etc/aria2c/aria2-linux.conf
sudo cp $HOME/dht.dat /etc/aria2c/dht.dat
echo "" |sudo tee /etc/aria2c/aria2.session
fi
sudo tee /etc/systemd/system/aria2c.service <<-'EOF'
[Unit]
Description=aria2c Service
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/aria2c --conf-path=/etc/aria2c/aria2-linux.conf
Restart=on-abnormal
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable aria2s.service
sudo systemctl start aria2s.service
fi  
