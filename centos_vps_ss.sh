#!/bin/bash
#安装依赖环境
yum -y install python-setuptools && easy_install shadowsocks
#安装tcptun
#yum install -y wget
#wget https://github.com/renjunyu/kcptun-shadowsocks-docker/raw/master/server_linux_amd64 -O /usr/bin/kcptun
#cp ./kcptun /usr/bin/kcptun
#chmod +x /usr/bin/kcptun

#设置supervisord   #change supervisord to systemd 
#easy_install supervisor
#mkdir -p /var/log/supervisor
#wget https://github.com/renjunyu/kcptun-shadowsocks-docker/raw/master/supervisord.conf -O /etc/supervisord.conf
#cp ./supervisord.conf /etc/supervisord.conf

#if [ ]; then
#下面一段是注释
tee /etc/systemd/system/ssserver.service <<-'EOF'
[Unit]
Description=ssserver Service
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ssserver -p !你自己的端口! -k !你自己的密码! -m aes-256-cfb
Restart=on-abnormal
[Install]
WantedBy=multi-user.target
EOF

#tee /etc/systemd/system/kcptun.service <<-'EOF'
#[Unit]
#Description=kcptun Service
#After=network.target
#Wants=network.target

#[Service]
#Type=simple
#ExecStart=/usr/bin/kcptun -l ":29900" -t "127.0.0.1:8989"  –mtu 1400 –sndwnd 2048 –rcvwnd 2048 -mode "fast2"
#Restart=on-abnormal
#[Install]
#WantedBy=multi-user.target
#EOF

systemctl daemon-reload
systemctl enable ssserver.service
systemctl start ssserver.service
#systemctl enable kcptun.service
#systemctl start kcptun.service
systemctl status ssserver.service
#systemctl status kcptun.service

#fi