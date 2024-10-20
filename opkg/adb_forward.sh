opkg install iptables
opkg install iptables-mod-nat-extra
opkg install adb
#opkg install curl

# Save connectivity checking script
cat <<"EOF" >/root/adb-watchdog.sh
#!/bin/sh
adb -a forward tcp:10086 tcp:10086
adb -a forward tcp:10000 tcp:10000
adb -a forward tcp:10808 tcp:10808
adb -a forward tcp:3000 tcp:3000
adb -a forward tcp:3333 tcp:3333
adb -a forward tcp:5555 tcp:5555
adb -a forward tcp:5900 tcp:5900
adb -a forward tcp:5244 tcp:5244
adb -a forward tcp:8022 tcp:8022
adb -a forward tcp:1122 tcp:1122
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.route_localnet=1
#清空原有规则以免重复
iptables -t nat -F
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 10086 -j DNAT --to-destination 127.0.0.1:10086
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 10000 -j DNAT --to-destination 127.0.0.1:10000
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 10808 -j DNAT --to-destination 127.0.0.1:10808
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 5555 -j DNAT --to-destination 127.0.0.1:5555
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 5900 -j DNAT --to-destination 127.0.0.1:5900
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 3000 -j DNAT --to-destination 127.0.0.1:3000
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 3333 -j DNAT --to-destination 127.0.0.1:3333
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 8022 -j DNAT --to-destination 127.0.0.1:8022
iptables -t nat -A PREROUTING -i br-lan -p tcp --dport 1122 -j DNAT --to-destination 127.0.0.1:1122
iptables-nft -t nat -F
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 10086 -j DNAT --to-destination 127.0.0.1:10086
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 10000 -j DNAT --to-destination 127.0.0.1:10000
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 10808 -j DNAT --to-destination 127.0.0.1:10808
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 5555 -j DNAT --to-destination 127.0.0.1:5555
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 5244 -j DNAT --to-destination 127.0.0.1:5244
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 5900 -j DNAT --to-destination 127.0.0.1:5900
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 3000 -j DNAT --to-destination 127.0.0.1:3000
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 3333 -j DNAT --to-destination 127.0.0.1:3333
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 8022 -j DNAT --to-destination 127.0.0.1:8022
iptables-nft -t nat -A PREROUTING -i br-lan -p tcp --dport 1122 -j DNAT --to-destination 127.0.0.1:1122

function network() {
	#超时时间
	local timeout=30

	#目标网站
	#local target=www.baidu.com
	local target=114.114.114.114

	#获取响应状态码
	#local ret_code=$(curl -I -s --connect-timeout ${timeout} ${target} -w %{http_code} | tail -n1)
	local ping_code=`ping -c 2 -W 5 $target|grep '64 bytes'|wc -l`

	#if [ "x$ret_code" = "x200" ]; then
		#网络畅通
	#	return 1
	#else
		#网络不畅通
	#	return 0
	#fi
	if [ ${ping_code} -ne 0 ];then
		#网络畅通
		return 1
	else
		#网络不畅通
		return 0
	fi
}

ANDROID_NAME=$(adb shell getprop ro.product.name)

if [ $ANDROID_NAME = 'gauguinpro' ]; then
	echo "is gauguinpro"
	network
	if [ $? -eq 0 ]; then
		echo "网络不畅"
		adb shell svc usb setFunctions rndis
		#adb shell svc power stayon usb
		adb shell input keyevent 26
	fi
else
  echo "not gauguinpro"
fi
EOF
chmod +x /root/adb-watchdog.sh

# Add cron job
cat <<"EOF" >>/etc/crontabs/root
* * * * * /root/adb-watchdog.sh
EOF
