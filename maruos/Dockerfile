FROM pdsouza/maruos-devbox
LABEL Author=sherylynn@outlook.com

USER root
WORKDIR /home/dev
#COPY sources.aliyun.list /etc/apt/sources.list
#RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

#RUN bash seafile_install_ubt.sh 
#apt的命令还是要集成在run中好，不然会出事
RUN sudo -s && \
    apt update -y && \
    apt install -y wget && \
    apt clean 

USER dev

CMD [ "/bin/bash" ]
#python2.7 ./seafile-server-6.2.4/setup-seafile-mysql.py
