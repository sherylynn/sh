apt install vim htop neovim curl -y
apt install termux-tools -y
#wget https://xeffyr.github.io/termux-x-repository/pubkey.gpg
#apt-key add pubkey.gpg
#apt update
cd ~
curl https://raw.githubusercontent.com/xeffyr/termux-x-repository/master/enablerepo.sh |sh
termux-setup-storage
