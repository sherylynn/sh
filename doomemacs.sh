#!/bin/bash
#rm ~/.emacs.d
rm -rf ~/.emacs.d
git clone https://github.com/plexus/chemacs2.git ~/.emacs.d
git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.emacs.d_doom
#ln -s ~/.emacs.d_doom ~/.emacs.d
git clone https://github.com/sherylynn/doom-private ~/.doom.d
~/.emacs.d_doom/bin/doom install

tee ~/.emacs-profiles.el <<-'EOF'
(("default"   . ((user-emacs-directory . "~/.emacs.d_doom")))
 ("doom" . ((user-emacs-directory . "~/.emacs.d_doom")))
 ("space"   . ((user-emacs-directory . "~/.emacs.d_space"))))
EOF
