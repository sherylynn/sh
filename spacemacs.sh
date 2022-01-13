#!/bin/bash
git clone -b develop https://github.com/syl20bnr/spacemacs ~/.emacs.d_space
rm ~/.emacs.d
ln -s ~/.emacs.d_space ~/.emacs.d
rm -rf ~/.spacemacs
git clone https://github.com/sherylynn/spacemacs-private ~/.spacemacs.d
