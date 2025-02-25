#/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew tap caskroom/cask
#normal app
brew cask install onyx skim iina firefox chromium calibre v2rayx qq wechat anydesk teamviewer telegram-desktop steam gimp squirrel visual-studio-code libreoffice virtualbox openshot-video-editor emacs
#macx86 app
brew cask install clover-configurator kext-utility hwsensors
#cli app
brew install ncdu nodejs go htop nload proxychains-ng mit-scheme #/usr/local/etc/proxychains.conf
#docker for amd-osx amd not support docker-ce
brew cask install docker-toolbox
#gnu
brew install evince macvim qemu
# android
brew cask install android-studio # android-ndk android-sdk
# dotnet
brew cask install dotnet-sdk
# frp
brew tap sherylynn/frp
brew install frp
cp ~/frpc.ini /usr/local/etc/frp/frpc.ini
brew services start frp
# v2ray
brew tap v2ray/v2ray
brew install v2ray-core
# need to add sudo before brew services
sudo brew services start v2ray-core
cp ~/config.json /usr/local/etc/v2ray/config.json
# wireguard
brew install wireguard-tools
<<'config_path'
/usr/local/etc/wireguard/xxx.conf
config_path
#emacs
brew tap railwaycat/emacsmacport
brew install emacs-mac --with-modules
ln -s /usr/local/opt/emacs-mac/Emacs.app /Applications/Emacs.app
brew tap d12frosted/emacs-plus
# emacs-plus 的包没做 with-tree-sitter 的参数识别
# 但是有了--with-modules 就没事 依然可以加载 tree-sitter
#brew install emacs-plus@29 --with-native-comp --with-tree-sitter
brew install emacs-plus@29 --with-native-comp

brew tap wez/wezterm
brew install --cask wez/wezterm/wezterm

#brew tap kde-mac/kde https://invent.kde.org/packaging/homebrew-kde.git
#brew install kdeconnect

#r 语言
brew install r
brew install rstudio
