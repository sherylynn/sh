#!/bin/bash
SCRIPT_NAME="ttyd"

sudo tee /etc/systemd/system/${SCRIPT_NAME}.service <<EOF
[Unit]
Description=${SCRIPT_NAME} Service
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
EOF

sudo tee -a /etc/systemd/system/${SCRIPT_NAME}.service <<EOF
Type=simple
PrivateTmp=true
Restart=on-abnormal
ExecStart=$(cd "$(dirname "$0")";pwd)/server_${SCRIPT_NAME}.sh
EOF

sudo tee -a /etc/systemd/system/${SCRIPT_NAME}.service <<-'EOF'
ProtectSystem=full

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable ${SCRIPT_NAME}.service
sudo systemctl restart ${SCRIPT_NAME}.service
sudo systemctl status ${SCRIPT_NAME}.service
./init_d_ttyd.sh
