#!/bin/bash
sudo apt install axel wget aria2 -y
FRP_VERSION=0.14.1
FRP_ARCH=amd64
Server=n
Client=n
Just_Install=n
#FRP_ARCH=arm
while getopts 'v:a:sc' OPT; do
  case $OPT in
    v)
      FRP_VERSION="$OPTARG";;
    a)
      FRP_ARCH="$OPTARG";;
    s)
      Server="y";;
    c)
      Client="y";;
    ?)
      echo "Usage: `basename $0` [options] filename"
  esac
done

shift $(($OPTIND - 1))

if [ ! -d "$HOME/frp" ]; then
aria2c https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz && \
#axel -n 10 https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz && \
    tar -xzf frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz && \
sudo mv frp_${FRP_VERSION}_linux_${FRP_ARCH} ~/frp && \
    rm frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz
fi

if [ ! -d "/etc/frp" ]; then
sudo mkdir /etc/frp
fi
sudo cp ~/frp/frps.ini /etc/frp/frps.ini
sudo cp ~/frp/frpc.ini /etc/frp/frpc.ini

sudo ln -s ~/frp/frps /usr/local/bin/frps
sudo ln -s ~/frp/frpc /usr/local/bin/frpc
if [ ${Server} = "y" ]; then  
sudo tee /etc/systemd/system/frps.service <<-'EOF'
[Unit]
Description=frps Service
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.ini
Restart=on-abnormal
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable frps.service
sudo systemctl start frps.service
fi  

if [ ${Client} = "y" ]; then 
sudo tee /etc/systemd/system/frpc.service <<-'EOF'
[Unit]
Description=frpc Service
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.ini
Restart=on-abnormal
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable frpc.service
sudo systemctl start frpc.service
fi