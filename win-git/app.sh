sudo apt install libgccjit0 libgccjit-8-dev librime-dev -y
brew install htop ncdu neovim
# for doom emacs
brew untap sherylynn/homebrew-emacsx11
brew tap sherylynn/homebrew-emacsx11
brew install emacsx11
brew install ripgrep git fd coreutils cmake libtool libvterm
# for vterm support
brew install gcc@5
# for doom emacs orgmode support mouse or M-x xterm-mouse-mode 
brew install tmux ttyd

sudo cp /home/linuxbrew/.linuxbrew/share/applications/emacs.desktop /usr/share/applications/
sudo chmod 777 /usr/share/applications/emacs.desktop
