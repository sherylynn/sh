FROM ubuntu
LABEL Author=sherylynn@outlook.com

WORKDIR /home
COPY sources.aliyun.list /etc/apt/sources.list

#RUN bash seafile_install_ubt.sh 
#apt的命令还是要集成在run中好，不然会出事
RUN apt update -y && \
    apt install -y wget && \
    wget http://seafile-downloads.oss-cn-shanghai.aliyuncs.com/seafile-server_6.2.4_x86-64.tar.gz && \
    mkdir haiwen && \
    mv seafile-server_* haiwen && \
    cd haiwen && \
    tar -xzf seafile-server_* && \
    mkdir installed && \
    mv seafile-server_* installed && \
    apt-get install -y python && \
    apt-get install -y python2.7 libpython2.7 python-setuptools python-imaging python-ldap python-urllib3 ffmpeg python-pip python-mysqldb python-memcache && \
    apt clean

RUN pip install pillow moviepy

#ADD seafile_config.sh /home/haiwen/seafile_config.sh
COPY build /home/build
WORKDIR /home/haiwen
EXPOSE 8082
EXPOSE 8000
CMD [ "/bin/bash" ]
#python2.7 ./seafile-server-6.2.4/setup-seafile-mysql.py