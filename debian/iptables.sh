#iptables -t nat -A PREROUTING -d 0.0.0.0 -p tcp --dport 24630 -j DNAT --to-destination 104.243.29.121:24630 
echo 1> /proc/sys/net/ipv4/ip_forward
sudo apt install iptables -y
pro='tcp'
NAT_Host=$(hostname -I)
#NAT_Host='10.0.0.12'
#NAT_Host='119.28.13.48'
#NAT_Port=24630
NAT_Port=$2
#Dst_Host='104.243.29.121'
Dst_Host=$1
Dst_Port=$2
iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -t nat -A PREROUTING -d $NAT_Host -p $pro --dport $NAT_Port -j DNAT --to-destination $Dst_Host:$Dst_Port
#iptables -t nat -A POSTROUTING -m $pro -p $pro --dport $Dst_Port -d $Dst_Host -j SNAT --to-source $NAT_Host
#iptables -t nat -A POSTROUTING -d 104.243.29.121 -p tcp --dport 24630 -j SNAT --to 0.0.0.0
