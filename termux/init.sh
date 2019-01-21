pkg install apt openssh -y
pkg install htop coreutils
#cat bashrc >> $HOME/.bashrc
mkdir -p ~/.termux
ln -s -f ~/sh/termux/termux.properties $HOME/termux.properties
ln -s -f ~/sh/termux/bashrc $HOME/.bashrc
