#/bin/bash
#base
yum update -y
yum install -y wget
wget http://seafile-downloads.oss-cn-shanghai.aliyuncs.com/seafile-server_6.2.4_x86-64.tar.gz
mkdir haiwen
mv seafile-server_* haiwen
cd haiwen
tar -xzf seafile-server_*
mkdir installed
mv seafile-server_* installed

#memcached
yum install gcc libffi-devel python-devel openssl-devel libmemcached libmemcached-devel
pip install pylibmc
pip install django-pylibmc

#clean
yum clean all



