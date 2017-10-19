/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

brew install nodejs yarn

mkdir ~/node-global
mkdir ~/node-cache
mkdir ~/yarn-cache

tee .bash_profile <<-'EOF'
if [ "${BASH-no}" != "no" ]; then  
    [ -r ~/.bashrc ] && . ~/.bashrc  
fi
EOF

echo 'export PATH="~/node-global/bin:$PATH"' >> ~/.bashrc
echo 'NPM_CONFIG_PREFIX=~/node-global' >> ~/.bashrc
echo 'NPM_CONFIG_CACHE=~/node-cache' >> ~/.bashrc
echo 'YARN_CACHE_FOLDER=~/yarn-cache' >> ~/.bashrc
source ~/.bashrc

#----------------------------
# Set Global packages path
#----------------------------
npm config set prefix "/Users/lynn/node-global"
npm config set cache "/Users/lynn/node-cache"
yarn config set cache-folder "/User/lynn/yarn-cache"

#----------------------------
# Install Basic cli packages
#----------------------------
npm i -g yrm --registry=https://registry.npm.taobao.org
yrm use taobao


npm i -g webpack http-server babel-cli pm2 typescript ts-node tslint eslint