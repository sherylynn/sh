#!/bin/bash
if [ ! -d "/mnt/hgfs" ]; then
sudo mkdir -p /mnt/hgfs
fi
sudo apt-get install open-vm-tools-desktop -y
sudo tee /etc/systemd/system/mnt.hgfs.service <<-'EOF'
[Unit]
Description=Load VMware shared folders
;open-vm-tools now has not these service
;Requires=vmware-vmblock-fuse.service
;After=vmware-vmblock-fuse.service
ConditionPathExists=.host:/
ConditionVirtualization=vmware

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=
ExecStart=/usr/bin/vmhgfs-fuse -o allow_other -o auto_unmount .host:/ /mnt/hgfs
;-o umask=000 
;专门的权限给777
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable mnt.hgfs.service
sudo systemctl start mnt.hgfs.service
