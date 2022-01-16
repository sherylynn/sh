#!/bin/bash
rm -rf ~/.emacs.d
git clone https://github.com/plexus/chemacs2.git ~/.emacs.d
git clone -b develop --depth 1 https://github.com/syl20bnr/spacemacs ~/.emacs.d_space
#rm ~/.emacs.d
#ln -s ~/.emacs.d_space ~/.emacs.d
rm -rf ~/.spacemacs
git clone https://github.com/sherylynn/spacemacs-private ~/.spacemacs.d

tee ~/.emacs-profiles.el <<-'EOF'
(("default"   . ((user-emacs-directory . "~/.emacs.d_space")))
 ("legacy" . ((user-emacs-directory . "~/.emacs.legacy")))
 ("spacemacs"   . ((user-emacs-directory . "~/.emacs.d_doom"))))
EOF
