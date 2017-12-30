#!/bin/bash
sudo apt install aria2 -y
GOGS_VERSION=0.11.34
GOGS_ARCH=amd64
Server=n
Client=n
Just_Install=n
#GOGS_ARCH=arm
while getopts 'v:a:sc' OPT; do
  case $OPT in
    v)
      GOGS_VERSION="$OPTARG";;
    a)
      GOGS_ARCH="$OPTARG";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

shift $(($OPTIND - 1))

if [ ! -d "$HOME/gogs" ]; then
aria2c https://dl.gogs.io/${GOGS_VERSION}/linux_${GOGS_ARCH}.tar.gz && \
    mv linux_${GOGS_ARCH}.tar.gz ~/gogs.tar.gz && \
    tar -xzf gogs.tar.gz && \
    rm gogs.tar.gz
fi

if [ ! -d "/etc/gogs" ]; then
sudo mkdir /etc/gogs
fi

sudo tee /etc/systemd/system/gogs.service <<-'EOF'
[Unit]
Description=gogs Service
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/home/'${USER}'/gogs/gogs web
Restart=on-abnormal
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable gogs.service
sudo systemctl start gogs.service