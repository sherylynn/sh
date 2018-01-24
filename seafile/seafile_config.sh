#/bin/bash
#download seafile
apt update -y
apt install -y wget
wget http://seafile-downloads.oss-cn-shanghai.aliyuncs.com/seafile-server_6.2.4_x86-64.tar.gz
if [ ! -d "/home/haiwen" ]; then
sudo mkdir /home/haiwen
fi
mv seafile-server_* haiwen
cd haiwen
tar -xzf seafile-server_*
mkdir installed
mv seafile-server_* installed
#configure
cd seafile-server-*
./setup-seafile-mysql.sh