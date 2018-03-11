# Pull base image.
FROM alpine
MAINTAINER Sherylynn <352281674@qq.com>

# set apk mirror on aliyun mirror for china users
RUN echo "http://mirrors.aliyun.com/alpine/latest-stable/main/" > /etc/apk/repositories

# install openssl and the complete wget
RUN apk --update add --no-cache bash
RUN sed -i -e "s/bin\/ash/bin\/bash/" /etc/passwd

ENV LANG zh_CN.UTF-8
# install openssl and the complete wget
RUN apk --update add --no-cache openssh openssh-sftp-server byobu tmux && \
    /bin/sed -i -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    /usr/bin/ssh-keygen -A && \
    #echo "source /etc/profile.d/color_prompt" > /etc/skel/.bashrc && \
    #echo "source /etc/profile.d/color_prompt" > /root/.bashrc && \
    #cp /etc/skel/.bashrc /root/.bashrc && \
    echo "root:fuck" | chpasswd && \
    su - root -c "byobu-launcher-install"
#add file
ADD build/.bashrc /root/.bashrc
ADD build/normal.sh /root/normal.sh
# expose ports for ssh
EXPOSE 22
CMD    ["/usr/sbin/sshd", "-D", "-e"]
