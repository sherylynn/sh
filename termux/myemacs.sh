#!/bin/bash
. $(dirname "$0")/win-git/toolsinit.sh
NAME=my
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
#rm ~/.emacs.d
rm -rf ~/.emacs.d
rm -rf /data/data/org.gnu.emacs/files/.emacs.d
git clone --depth 1 https://github.com/plexus/chemacs2.git ~/.emacs.d
git clone --depth 1 https://github.com/plexus/chemacs2.git /data/data/org.gnu.emacs/files/.emacs.d
git clone --depth 1 https://github.com/sherylynn/myemacs.d.git ~/.emacs.d_my
git clone --depth 1 https://github.com/sherylynn/myemacs.d.git /data/data/org.gnu.emacs/files/.emacs.d_my
#ln -s ~/.emacs.d_doom ~/.emacs.d
#git clone https://github.com/sherylynn/doom-private ~/.doom.d
#~/.emacs.d_doom/bin/doom install

#还需要加入earlyinit
#映射了也没用，termux中无法直接emacs，我也不是doom，用不到
#ln -s /data/data/org.gnu.emacs/lib/libandroid-emacs.so /data/data/com.termux/files/usr/bin/emacs
tee ~/.emacs-profiles.el <<-'EOF'
(("default"   . ((user-emacs-directory . "~/.emacs.d_my")))
 ("doom" . ((user-emacs-directory . "~/.emacs.d_doom")))
 ("space"   . ((user-emacs-directory . "~/.emacs.d_space"))))
EOF
tee /data/data/org.gnu.emacs/files/.emacs-profiles.el <<-'EOF'
(("default"   . ((user-emacs-directory . "~/.emacs.d_my")))
 ("doom" . ((user-emacs-directory . "~/.emacs.d_doom")))
 ("space"   . ((user-emacs-directory . "~/.emacs.d_space"))))
EOF
#SOFT_BIN=~/.emacs.d_doom/bin
#echo 'export PATH=$PATH:'${SOFT_BIN}>${TOOLSRC}