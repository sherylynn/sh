#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
. $(dirname "$0")/cli.sh
#. ./cli.sh

termux_data_path=/data/data/com.termux/files/home/storage/downloads

termux_gitcredentials=$termux_data_path/.git-credentials
termux_gitconfig=$termux_data_path/.gitconfig
termux_rime=$termux_data_path/rime
sdcard_rime=$SDCARD_DIR/rime

#test -f $termux_gitconfig && sudo cp $termux_gitconfig $DEBIAN_DIR/root/
#test -f $termux_gitcredentials && sudo cp $termux_gitcredentials $DEBIAN_DIR/root/
#复用输入法词库
sudo rm -rf $DEBIAN_DIR/root/rime

#直接link后在chroot里访问不到
test -d $sdcard_rime && sudo ln -s $sdcard_rime $DEBIAN_DIR/root/rime
