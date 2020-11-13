pkg install apt openssh -y
pkg install htop coreutils tsu getconf vim zsh git -y
pkg install lua5.3 -y
ln -s /data/data/com.termux/files/usr/bin/lua5.3 /data/data/com.termux/files/usr/bin/lua
#cat bashrc >> $HOME/.bashrc
chsh -s zsh
mkdir -p ~/.termux
mkdir -p ~/bin
ln -s -f ~/sh/termux/termux.properties $HOME/.termux/termux.properties
ln -s -f /data/data/com.termux/files/usr/bin/nvim $HOME/bin/termux-file-editor
termux-setup-storage
#ln -s -f ~/sh/termux/bashrc $HOME/.bashrc
