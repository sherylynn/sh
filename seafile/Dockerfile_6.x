FROM ubuntu
LABEL Author=sherylynn@outlook.com

WORKDIR /home
#COPY sources.aliyun.list /etc/apt/sources.list
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

#RUN bash seafile_install_ubt.sh 
#apt的命令还是要集成在run中好，不然会出事
RUN apt update -y && \
    apt install -y wget && \
    apt clean && \
    wget http://seafile-downloads.oss-cn-shanghai.aliyuncs.com/seafile-server_7.0.5_x86-64.tar.gz && \
    mkdir haiwen && \
    mv seafile-server_* haiwen && \
    cd haiwen && \
    tar -xzf seafile-server_* && \
    mkdir installed && \
    mv seafile-server_* installed
RUN apt update -y && \
    apt-get install -y python && \
    apt clean
RUN apt update -y && \
    apt-get install -y python2.7 libpython2.7 python-setuptools python-imaging python-ldap python-urllib3 python-pip python-mysqldb python-memcache python-requests && \
    apt clean
RUN apt update -y && \
    apt install ffmpeg -y && \ 
    apt clean

RUN pip install pillow moviepy

#ADD seafile_config.sh /home/haiwen/seafile_config.sh
ADD build/backup.sh   /home/haiwen/backup.sh
ADD build/recovery.sh /home/haiwen/recovery.sh
ADD build/start.sh    /home/haiwen/start.sh
ADD build/stop.sh     /home/haiwen/stop.sh
ADD build/init.sh     /home/haiwen/init.sh

WORKDIR /home/haiwen

RUN chmod 777 backup.sh recovery.sh start.sh stop.sh init.sh

EXPOSE 8082
EXPOSE 8000
CMD [ "/bin/bash" ]
#python2.7 ./seafile-server-6.2.4/setup-seafile-mysql.py
