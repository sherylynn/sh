#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
#影响treesit, treesit需要随时用clang编译,不适合删除
#apt remove build-essential cmake -y
apt autoremove -y
apt clean
#可能删掉字体，不删了
#rm -rf $(cache_folder)
