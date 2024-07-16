pkg install apt openssh -y
pkg install htop ncdu coreutils tsu getconf vim zsh git wget curl -y
#termux-api
#pkg install nodejs golang python
#pkg install tmux ttyd termux-services -y
pkg install termux-services -y

#tee /data/data/com.termux/files/usr/etc/ssh/sshd_config <<-'EOF'
#PrintMotd yes
#Port 8022
#PermitRootLogin yes
#PasswordAuthentication yes
##PubkeyAuthentication yes
##AuthorizedKeysFile /data/authorized_keys
#StrictModes no
#Subsystem sftp /data/data/com.termux/files/usr/libexec/sftp-server
#EOF
#echo "root passwd"
#sudo passwd
#sv-disable sshd
#sv down sshd
sv-enable sshd
echo "normal passwd"
passwd
#doom emacs
#pkg install emacs ripgrep fd librime gflags -y
pkg install lua53 -y
ln -s /data/data/com.termux/files/usr/bin/lua5.3 /data/data/com.termux/files/usr/bin/lua
#cat bashrc >> $HOME/.bashrc
chsh -s zsh
mkdir -p ~/.termux
mkdir -p ~/bin
ln -s -f ~/sh/termux/termux.properties $HOME/.termux/termux.properties
#ln -s -f /data/data/com.termux/files/usr/bin/nvim $HOME/bin/termux-file-editor
#termux-setup-storage
#ln -s -f ~/sh/termux/bashrc $HOME/.bashrc
