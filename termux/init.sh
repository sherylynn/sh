pkg install apt openssh -y
pkg install htop coreutils tsu vim zsh lua -y
#cat bashrc >> $HOME/.bashrc
chsh -s zsh
mkdir -p ~/.termux
ln -s -f ~/sh/termux/termux.properties $HOME/.termux/termux.properties
#ln -s -f ~/sh/termux/bashrc $HOME/.bashrc
