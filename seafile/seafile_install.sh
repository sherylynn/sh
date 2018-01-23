#/bin/bash
#download seafile
yum update -y
yum install -y wget
wget http://seafile-downloads.oss-cn-shanghai.aliyuncs.com/seafile-server_6.2.4_x86-64.tar.gz
mkdir haiwen
mv seafile-server_* haiwen
cd haiwen
tar -xzf seafile-server_*
mkdir installed
mv seafile-server_* installed

#base tool
yum -y install epel-release
rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
yum -y install python-imaging MySQL-python python-memcached python-ldap python-urllib3 ffmpeg ffmpeg-devel
pip install pillow moviepy

#memcached
yum install gcc libffi-devel python-devel openssl-devel libmemcached libmemcached-devel
pip install pylibmc
pip install django-pylibmc

#clean
yum clean all



