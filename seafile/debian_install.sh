#/bin/bash
#download seafile
sudo apt update -y
sudo apt install -y wget
cd ~
wget http://seafile-downloads.oss-cn-shanghai.aliyuncs.com/seafile-server_6.2.4_x86-64.tar.gz
mkdir haiwen
mv seafile-server_* haiwen
cd haiwen
tar -xzf seafile-server_*
mkdir installed
mv seafile-server_* installed

#base tool
sudo apt-get update -y
sudo apt-get install -y python
sudo apt-get install -y python2.7 libpython2.7 python-setuptools python-imaging python-ldap python-urllib3 ffmpeg python-pip python-mysqldb python-memcache
pip install pillow moviepy

#clean
sudo apt clean



