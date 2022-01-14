#!/bin/bash
git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.emacs.d_doom
rm ~/.emacs.d
ln -s ~/.emacs.d_doom ~/.emacs.d
~/.emacs.d/bin/doom install
