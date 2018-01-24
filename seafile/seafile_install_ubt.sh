#/bin/bash
#download seafile
apt update -y
apt install -y wget
wget http://seafile-downloads.oss-cn-shanghai.aliyuncs.com/seafile-server_6.2.4_x86-64.tar.gz
mkdir haiwen
mv seafile-server_* haiwen
cd haiwen
tar -xzf seafile-server_*
mkdir installed
mv seafile-server_* installed

#base tool
apt-get update -y
apt-get install python -y
apt-get install python2.7 libpython2.7 python-setuptools python-imaging python-ldap python-urllib3 ffmpeg python-pip python-mysqldb python-memcache -y
pip install pillow moviepy

#clean
apt clean



