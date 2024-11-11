#!/data/data/com.termux/files/usr/bin/bash
. $(dirname "$0")/../../win-git/toolsinit.sh
. $(dirname "$0")/cli.sh
#. ./cli.sh

termux_data_path=/data/data/com.termux/files/home/storage/downloads

termux_gitcredentials=$termux_data_path/.git-credentials
termux_gitconfig=$termux_data_path/.gitconfig
termux_rime=$termux_data_path/rime
#sdcard的目录在termux和chroot中都可以访问
#直接termux中的目录似乎在chroot中无法访问
sdcard_gitcredentials=$termux_data_path/.git-credentials
sdcard_gitconfig=$termux_data_path/.gitconfig
sdcard_rime=$SDCARD_DIR/rime

sudo rm -rf $DEBIAN_DIR/root/.gitconfig
sudo rm -rf $DEBIAN_DIR/root/.git-credentials
#test -f $termux_gitconfig && sudo cp $termux_gitconfig $DEBIAN_DIR/root/
#test -f $termux_gitcredentials && sudo cp $termux_gitcredentials $DEBIAN_DIR/root/
test -f $sdcard_gitconfig && sudo ln -s $sdcard_gitconfig $DEBIAN_DIR/root/
test -f $sdcard_gitcredentials && sudo ln -s $sdcard_gitcredentials $DEBIAN_DIR/root/
#复用输入法词库
sudo rm -rf $DEBIAN_DIR/root/rime

#直接link后在chroot里访问不到
#test -d $termux_rime && sudo ln -s $termux_rime $CHROOT_DIR/root/rime
test -d $sdcard_rime && sudo ln -s $sdcard_rime $DEBIAN_DIR/root/
