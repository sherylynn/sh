#!/bin/bash
. $(dirname "$0")/win-git/toolsinit.sh
NAME=my
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
#rm ~/.emacs.d
rm -rf ~/.emacs.d
#git clone --depth 1 https://github.com/plexus/chemacs2.git ~/.emacs.d
git clone --depth 1 https://github.com/sherylynn/myemacs.d.git ~/.emacs.d_my
ln -s ~/.emacs.d_my ~/.emacs.d

git clone --depth 1 https://github.com/iDvel/rime-ice ~/rime
#ln -s ~/.emacs.d_doom ~/.emacs.d
#git clone https://github.com/sherylynn/doom-private ~/.doom.d
#~/.emacs.d_doom/bin/doom install

tee ~/.emacs-profiles.el <<-'EOF'
(("default"   . ((user-emacs-directory . "~/.emacs.d_my")))
 ("doom" . ((user-emacs-directory . "~/.emacs.d_doom")))
 ("space"   . ((user-emacs-directory . "~/.emacs.d_space"))))
EOF
#SOFT_BIN=~/.emacs.d_doom/bin
#echo 'export PATH=$PATH:'${SOFT_BIN}>${TOOLSRC}
