useradd lynn && passwd lynn

systemclt start firewalld.service
firewall-cmd --get-active-zones
firewall-cmd --list-ports
#firewall-cmd --zone=dmz --add-service=http --permanent
#firewall-cmd --zone=dmz --add-service=https --permanent
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --zone=public --add-port=26408/tcp --permanent
firewall-cmd --zone=public --add-port=28000/tcp --permanent
firewall-cmd --zone=public --add-port=29000/tcp --permanent
firewall-cmd --zone=public --add-port=7000/tcp --permanent
firewall-cmd --zone=public --add-port=8000/tcp --permanent
firewall-cmd --zone=public --add-port=8082/tcp --permanent
firewall-cmd --reload

yum update -y
yum insgtall -y iptraf
iptraf-ng