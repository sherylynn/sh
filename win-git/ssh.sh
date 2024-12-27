#!/bin/bash
. $(dirname "$0")/toolsinit.sh
mkdir -p ~/.ssh
#cat ~/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
#chmod 600 ~/.ssh/authorized_keys
#sudo apt purge openssh-server -y
#sudo apt install openssh-server -y
update_config /etc/ssh/sshd_config Port 22 sudo
update_config /etc/ssh/sshd_config PasswordAuthentication yes sudo
update_config /etc/ssh/sshd_config PermitRootLogin yes sudo
#update_config /etc/ssh/sshd_config AcceptEnv LANG sudo

#sudo service ssh --full-restart
#sudo systemctl restart ssh

sudo killall sshd
/usr/sbin/sshd -p 22
