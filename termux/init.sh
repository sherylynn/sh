pkg install apt openssh -y
pkg install htop coreutils tsu vim zsh lua git -y
#cat bashrc >> $HOME/.bashrc
chsh -s zsh
mkdir -p ~/.termux
mkdir -p ~/bin
ln -s -f ~/sh/termux/termux.properties $HOME/.termux/termux.properties
ln -s -f /data/data/com.termux/files/usr/bin/nvim $HOME/bin/termux-file-editor
#ln -s -f ~/sh/termux/bashrc $HOME/.bashrc
