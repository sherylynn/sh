opkg install iptables
opkg install iptables-mod-nat-extra


# Save connectivity checking script
cat << "EOF" > /root/adb-watchdog.sh
#!/bin/sh
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.route_localnet=1
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 10086 -j DNAT --to-destination 127.0.0.1:10086
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 5900 -j DNAT --to-destination 127.0.0.1:5900
EOF
chmod +x /root/adb-watchdog.sh
 
# Add cron job
cat << "EOF" >> /etc/crontabs/root
* * * * * /root/adb-watchdog.sh
EOF
