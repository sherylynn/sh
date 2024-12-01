#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
. $(dirname "$0")/cli.sh
sudo rurima docker pull -m dockerpull.org -i debian -s ./test
