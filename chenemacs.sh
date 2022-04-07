#!/bin/bash
. $(dirname "$0")/win-git/toolsinit.sh
NAME=doom
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
rm -rf ~/.emacs.d
git clone --depth 1 https://github.com/plexus/chemacs2.git ~/.emacs.d
git clone --depth 1 https://github.com/redguardtoo/emacs.d.git ~/.emacs.d_chen

tee ~/.emacs-profiles.el <<-'EOF'
(("default"   . ((user-emacs-directory . "~/.emacs.d_chen")))
 ("doom" . ((user-emacs-directory . "~/.emacs.d_doom")))
 ("space"   . ((user-emacs-directory . "~/.emacs.d_space"))))
EOF
