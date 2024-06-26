#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
NAME=my
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
#rm ~/.emacs.d
rm -rf ~/.emacs.d
#git clone --depth 1 https://github.com/plexus/chemacs2.git ~/.emacs.d
git clone --depth 1 https://github.com/sherylynn/myemacs.d.git ~/.emacs.d_my
ln -s ~/.emacs.d_my ~/.emacs.d
