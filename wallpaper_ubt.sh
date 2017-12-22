sudo tee /usr/local/bin/autowallpaper <<-'EOF'
#!/bin/bash
Size=1000
Url=http://picsum.photos/${Size}/?random
WALLS_PATH=/etc/Wallpapers
if [ ! -d "${WALLS_PATH}" ]; then
mkdir $WALLS_PATH
fi
wget $Url -O ${WALLS_PATH}/${Size}.jpg

gsettings set org.gnome.desktop.background picture-uri "file://${WALLS_PATH}/${Size}.jpg"
EOF

sudo tee /etc/systemd/system/autowallpaper.service <<-'EOF'
[Unit]
Description=autowallpaper Service

[Service]
Type=simple
ExecStart=/usr/local/bin/autowallpaper
[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/autowallpaper.timer <<-'EOF'
[Unit]
Description=autowallpaper Timer
[Timer]
OnBootSec=5min
OnUnitActiveSec=1min
Unit=autowallpaper.service
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl start autowallpaper.timer
sudo systemctl enable autowallpaper.timer