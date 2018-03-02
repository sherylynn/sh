pkg install apt openssh -y
cat id_rsa.pub >> $HOME/.ssh/authorized_keys
sshd