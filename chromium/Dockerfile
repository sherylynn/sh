FROM ubuntu:14.04
LABEL Author=sherylynn@outlook.com

WORKDIR /home
COPY sources.aliyun.list /etc/apt/sources.list

#RUN bash seafile_install_ubt.sh 
#apt的命令还是要集成在run中好，不然会出事
RUN apt update -y && \
    apt install -y git curl wget vim python && \
    apt-get clean

#need proxy
#RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git

RUN echo 'export PATH="$PATH:/home/depot_tools"' >> ~/.bashrc
#mkdir workpath
RUN mkdir chromium
#ADD init.sh /home/init.sh
ADD build/init.sh /home/init.sh
ADD build/proxy.sh /home/proxy.sh
ADD build/fetch.sh /home/fetch.sh

RUN chmod 777 init.sh proxy.sh fetch.sh

WORKDIR /home/chromium

EXPOSE 8082
EXPOSE 8000
CMD [ "/bin/bash" ]
#python2.7 ./seafile-server-6.2.4/setup-seafile-mysql.py
