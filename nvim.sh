#通用安装模式
#先是centos
sudo yum --enablerepo=epel -y install fuse-sshfs # install from EPEL
user="$(whoami)"
usermod -a -G fuse "$user" 

#包依赖方法不知道为什么不灵 说有些包获取不到
#sudo yum -y install epel-release
#curl -o /etc/yum.repos.d/dperson-neovim-epel-7.repo https://copr.fedorainfracloud.org/coprs/dperson/neovim/repo/epel-7/dperson-neovim-epel-7.repo 
#sudo yum -y install neovim

if [ ! -d "$HOME/nvim" ]; then
sudo mkdir $HOME/nvim
fi
cd $HOME/nvim
curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage
chmod u+x nvim.appimage
sudo tee -a ~/.bashrc <<-"EOF"
PATH="$HOME/nvim:$PATH"
alias vim=nvim.appimage
EOF