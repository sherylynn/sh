FROM ubuntu
LABEL Author=sherylynn@outlook.com

WORKDIR /home
#COPY sources.aliyun.list /etc/apt/sources.list
#RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

#RUN bash seafile_install_ubt.sh 
#apt的命令还是要集成在run中好，不然会出事
RUN apt update -y && \
    apt install -y wget && \
    apt clean 

RUN wget http://seafile-downloads.oss-cn-shanghai.aliyuncs.com/seafile-server_7.1.1_x86-64.tar.gz && \
    mkdir haiwen && \
    mv seafile-server_* haiwen && \
    cd haiwen && \
    tar -xzf seafile-server_* && \
    mkdir installed && \
    mv seafile-server_* installed

RUN apt-get install -y python3 python3-setuptools python3-pip python3-ldap && \
    apt clean
#RUN apt update -y && \
#    apt install ffmpeg -y && \ 
#    apt clean

RUN pip3 install --timeout=3600 Pillow pylibmc captcha jinja2 sqlalchemy psd-tools \
    django-pylibmc django-simple-captcha

#ADD seafile_config.sh /home/haiwen/seafile_config.sh
ADD build/backup.sh   /home/haiwen/backup.sh
ADD build/recovery.sh /home/haiwen/recovery.sh
ADD build/start.sh    /home/haiwen/start.sh
ADD build/stop.sh     /home/haiwen/stop.sh
ADD build/init.sh     /home/haiwen/init.sh
ADD build/patch.sh     /home/haiwen/patch.sh

WORKDIR /home/haiwen

RUN chmod 777 backup.sh recovery.sh start.sh stop.sh init.sh

EXPOSE 8082
EXPOSE 8000
CMD [ "/bin/bash" ]
#python2.7 ./seafile-server-6.2.4/setup-seafile-mysql.py
