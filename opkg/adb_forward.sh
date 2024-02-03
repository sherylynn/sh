opkg install iptables
opkg install iptables-mod-nat-extra
opkg install adb


# Save connectivity checking script
cat << "EOF" > /root/adb-watchdog.sh
#!/bin/sh
adb -a forward tcp:10086 tcp:10086
adb -a forward tcp:10808 tcp:10808
adb -a forward tcp:3000 tcp:3000
adb -a forward tcp:5555 tcp:5555
adb -a forward tcp:5900 tcp:5900
adb -a forward tcp:5244 tcp:5244
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.route_localnet=1
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 10086 -j DNAT --to-destination 127.0.0.1:10086
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 10808 -j DNAT --to-destination 127.0.0.1:10808
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 5555 -j DNAT --to-destination 127.0.0.1:5555
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 5900 -j DNAT --to-destination 127.0.0.1:5900
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 3000 -j DNAT --to-destination 127.0.0.1:3000
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 10086 -j DNAT --to-destination 127.0.0.1:10086
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 10808 -j DNAT --to-destination 127.0.0.1:10808
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 5555 -j DNAT --to-destination 127.0.0.1:5555
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 5244 -j DNAT --to-destination 127.0.0.1:5244
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 5900 -j DNAT --to-destination 127.0.0.1:5900
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 3000 -j DNAT --to-destination 127.0.0.1:3000
EOF
chmod +x /root/adb-watchdog.sh
 
# Add cron job
cat << "EOF" >> /etc/crontabs/root
* * * * * /root/adb-watchdog.sh
EOF



cat << "EOF" > /root/adb-wan_check.sh
#!/bin/sh
function network() {
	#超时时间
	local timeout=30

	#目标网站
	local target=www.baidu.com

	#获取响应状态码
	local ret_code=$(curl -I -s --connect-timeout ${timeout} ${target} -w %{http_code} | tail -n1)

	if [ "x$ret_code" = "x200" ]; then
		#网络畅通
		return 1
	else
		#网络不畅通
		return 0
	fi

	return 0
}

network
if [ $? -eq 0 ]; then
  adb shell svc usb setFunctions rndis
  adb shell svc power stayon usb
fi
EOF
chmod +x /root/adb-wan_check.sh

cat << "EOF" >> /etc/crontabs/root
* * * * * /root/adb-wan_check.sh
EOF
