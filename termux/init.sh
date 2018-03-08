pkg install apt openssh -y
cat $HOME/id_rsa.pub >> $HOME/.ssh/authorized_keys
cat bashrc >> $HOME/.bashrc
sshd
