#!/bin/bash
sudo yum groupinstall -y 'Development Tools' && sudo yum install -y curl file git
git clone https://github.com/Linuxbrew/brew.git ~/.linuxbrew
sudo tee -a ~/.bashrc <<-"EOF"
PATH="$HOME/.linuxbrew/bin:$PATH"
export MANPATH="$(brew --prefix)/share/man:$MANPATH"
export INFOPATH="$(brew --prefix)/share/info:$INFOPATH"
EOF

#不能在root下运行,白瞎