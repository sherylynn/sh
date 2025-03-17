. $(dirname "$0")/../win-git/toolsinit.sh
NAME=homebrew
SOFT_ROOT=/opt/homebrew/bin
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
brew uninstall --force $(brew list)
brew cleanup
sudo rm -rf /opt/homebrew
cd ~
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#curl -LJO https://github.com/Homebrew/brew/archive/refs/tags/4.1.0.zip
#unzip brew-4.1.0.zip
#sudo mv brew-4.1.0 /opt/homebrew
#sudo chown -R $(whoami) /opt/homebrew

export HOMEBREW_NO_INSTALL_FROM_API=1
#export PATH=$SOFT_ROOT:$PATH
/opt/homebrew/bin/brew doctor
#cd /opt/homebrew/Library/Taps/homebrew/homebrew-core
#git checkout 9dac08fd00e3fd1f7c419e0d93249f9614f89500
git -C $(/opt/homebrew/bin/brew --repo homebrew/core) checkout 9dac08fd00e3fd1f7c419e0d93249f9614f89500 
#export HOMEBREW_BREW_GIT_REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
#export HOMEBREW_CORE_GIT_REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git
#export HOMEBREW_API_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api
#export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles
echo "export PATH=$SOFT_ROOT:"'$PATH' >${TOOLSRC}
echo "export HOMEBREW_NO_INSTALL_FROM_API=1">>${TOOLSRC}
echo "export HOMEBREW_NO_INSTALL_CLEANUP=1">>${TOOLSRC}

