#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
#. ./cli.sh
. $(dirname "$0")/cli.sh

. $(dirname "$0")/unchroot.sh
. $(dirname "$0")/unchroot.sh
. $(dirname "$0")/unchroot.sh
#./unchroot.sh

#sudo rm -rf ~/Desktop/chrootdebian/
sudo rm -rf $DEBIAN_DIR
#proot-distro reset debian
proot-distro remove debian
proot-distro remove debian
