sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.route_localnet=1
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 10086 -j DNAT --to-destination 127.0.0.1:10086
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 5900 -j DNAT --to-destination 127.0.0.1:5900
