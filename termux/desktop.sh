wget https://xeffyr.github.io/termux-x-repository/pubkey.gpg
apt-key add pubkey.gpg
apt update
curl https://raw.githubusercontent.com/xeffyr/termux-x-repository/master/enablerepo.sh |sh
pkg install termux-desktop

