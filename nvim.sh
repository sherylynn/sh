#通用安装模式
#先是centos
sudo yum --enablerepo=epel -y install fuse-sshfs # install from EPEL
user="$(whoami)"
usermod -a -G fuse "$user" 

if [ ! -d "$HOME/nvim" ]; then
sudo mkdir $HOME/nvim
fi
cd $HOME/nvim
curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage
chmod u+x nvim.appimage
sudo tee -a ~/.bashrc <<-"EOF"
PATH="$HOME/nvim:$PATH"
EOF