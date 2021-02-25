#!/bin/bash
SCRIPT_NAME="code-server"
while getopts 'n:a:sc' OPT; do
  case $OPT in
    n)
      SCRIPT_NAME="$OPTARG";;
    h)
      REVOLUTION_HIGH="$OPTARG";;
    s)
      Server="y";;
    c)
      Client="y";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

sudo tee /etc/systemd/system/${SCRIPT_NAME}.service <<EOF
[Unit]
Description=${SCRIPT_NAME} Service
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
EOF

sudo tee -a /etc/systemd/system/${SCRIPT_NAME}.service <<EOF
User=$(whoami)
;Group=$(id -g -n)
Type=simple
;ExecStartPre=/bin/bash --login -c 'env > /tmp/.new-env-file'
;EnvironmentFile=$HOME/.env.file
PrivateTmp=true
Restart=on-abnormal
ExecStart=$(cd "$(dirname "$0")";pwd)/server_${SCRIPT_NAME}.sh
EOF

sudo tee -a /etc/systemd/system/${SCRIPT_NAME}.service <<-'EOF'
; Hide /home, /root, and /run/user. Nobody will steal your SSH-keys.
;ProtectHome=true
;after protect even if this script can not read home
; Make /usr, /boot, /etc and possibly some more folders read-only.
ProtectSystem=full

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable ${SCRIPT_NAME}.service
sudo systemctl restart ${SCRIPT_NAME}.service
sudo systemctl status ${SCRIPT_NAME}.service
