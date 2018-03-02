pkg install apt openssh
cat id_rsa.pub >> $HOME/.ssh/authorized_keys
sshd