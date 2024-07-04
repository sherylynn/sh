#sudo apt install libgccjit0 libgccjit-8-dev librime-dev -y
sudo apt install librime-dev -y
brew install htop ncdu vim
# for doom emacs
brew untap sherylynn/homebrew-emacsx11
brew tap sherylynn/homebrew-emacsx11
brew install emacsx11
brew install ripgrep git fd coreutils cmake libtool libvterm
# for vterm support
# brew install gcc@5
# for doom emacs orgmode support mouse or M-x xterm-mouse-mode 
brew install tmux ttyd

sudo tee /usr/share/applications/spark-store.desktop <<-'EOF'
[Desktop Entry]
Name=Emacs
GenericName=Text Editor
Comment=Edit text
MimeType=text/english;text/plain;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;
#Exec=eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && emacs %F
Exec=/home/linuxbrew/.linuxbrew/bin/emacs
Icon=emacs
Type=Application
Terminal=false
Categories=Development;TextEditor;
StartupWMClass=Emacs
EOF
fi

sudo chmod 777 /usr/share/applications/emacs.desktop
