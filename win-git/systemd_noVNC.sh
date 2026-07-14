#!/bin/bash
SCRIPT_NAME="noVNC"
SCRIPT_DIR=$(
  cd "$(dirname "$0")"
  pwd
)
CURRENT_USER=$(whoami)
CURRENT_UID=$(id -u)

# 禁用 xfce-autostart.service（如果存在），避免与 noVNC.service 冲突
if systemctl list-unit-files xfce-autostart.service &>/dev/null; then
  echo "禁用 xfce-autostart.service ..."
  sudo systemctl disable --now xfce-autostart.service 2>/dev/null || true
fi

sudo tee /etc/systemd/system/${SCRIPT_NAME}.service <<EOF
[Unit]
Description=${SCRIPT_NAME} Service
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
User=${CURRENT_USER}
Type=simple
WorkingDirectory=${SCRIPT_DIR}
Environment=HOME=${HOME}
Environment=PATH=/usr/local/bin:/usr/bin:/bin:${HOME}/tools/bin
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${CURRENT_UID}/bus
ProtectSystem=false
Restart=on-abnormal
ExecStart=/bin/bash ${SCRIPT_DIR}/server_${SCRIPT_NAME}.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ${SCRIPT_NAME}.service
sudo systemctl restart ${SCRIPT_NAME}.service
sudo systemctl status ${SCRIPT_NAME}.service
