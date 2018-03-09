pkg install apt openssh -y
pkg install htop coreutils
cat $HOME/id_rsa.pub >> $HOME/.ssh/authorized_keys
cat bashrc >> $HOME/.bashrc
sshd
