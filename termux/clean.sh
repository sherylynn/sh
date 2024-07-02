#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
apt remove build-essential cmake -y
apt autoremove -y
apt clean
rm -rf $(cache_folder)
