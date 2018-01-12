#!/bin/bash
if [ ! -d "/mnt/hgfs" ]; then
sudo mkdir -p /mnt/hgfs
fi
sudo apt-get install open-vm-tools-desktop -y
sudo tee /etc/systemd/system/mnt.hgfs.service <<-'EOF'
[Unit]
Description=Load VMware shared folders
Requires=vmware-vmblock-fuse.service
After=vmware-vmblock-fuse.service
ConditionPathExists=.host:/
ConditionVirtualization=vmware

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=
ExecStart=/usr/bin/vmhgfs-fuse -o allow_other -o auto_unmount .host:/ /mnt/hgfs

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable mnt.hgfs.service
sudo systemctl start mnt.hgfs.service