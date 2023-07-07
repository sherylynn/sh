opkg install iptables
opkg install iptables-mod-nat-extra


# Save connectivity checking script
cat << "EOF" > /root/adb-watchdog.sh
#!/bin/sh
adb -a forward tcp:10086 tcp:10086
adb -a forward tcp:3000 tcp:3000
adb -a forward tcp:5900 tcp:5900
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.route_localnet=1
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 10086 -j DNAT --to-destination 127.0.0.1:10086
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 5900 -j DNAT --to-destination 127.0.0.1:5900
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 3000 -j DNAT --to-destination 127.0.0.1:3000
EOF
chmod +x /root/adb-watchdog.sh
 
# Add cron job
cat << "EOF" >> /etc/crontabs/root
* * * * * /root/adb-watchdog.sh
EOF
