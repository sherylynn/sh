FROM centos
LABEL Author=sherylynn@outlook.com

WORKDIR /home
COPY seafile_install.sh \
     /home/

RUN bash seafile_install.sh && \
    ls

ADD seafile_config.sh /home/haiwen/seafile_config.sh

WORKDIR /home/haiwen
EXPOSE 8082
EXPOSE 8000
CMD [ "/bin/bash" ]