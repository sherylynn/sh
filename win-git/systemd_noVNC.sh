#!/bin/bash
SCRIPT_NAME="noVNC"

sudo tee /etc/systemd/system/${SCRIPT_NAME}.service <<EOF
[Unit]
Description=${SCRIPT_NAME} Service
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
EOF

SCRIPT_DIR=$(
  cd "$(dirname "$0")"
  pwd
)

sudo tee -a /etc/systemd/system/${SCRIPT_NAME}.service <<EOF
User=$(whoami)
Type=simple
WorkingDirectory=${SCRIPT_DIR}
Environment=DISPLAY=:5
Environment=HOME=$HOME
Environment=PATH=/usr/local/bin:/usr/bin:/bin:$HOME/tools/bin
ProtectSystem=false
Restart=on-abnormal
ExecStart=/bin/bash ${SCRIPT_DIR}/server_${SCRIPT_NAME}.sh
EOF

sudo tee -a /etc/systemd/system/${SCRIPT_NAME}.service <<-'EOF'
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable ${SCRIPT_NAME}.service
sudo systemctl restart ${SCRIPT_NAME}.service
sudo systemctl status ${SCRIPT_NAME}.service
