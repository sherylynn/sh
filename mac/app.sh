#/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew tap caskroom/cask
#normal app
brew cask install onyx skim iina firefox chromium calibre v2rayx qq wechat anydesk teamviewer visual-studio-code telegram-desktop steam gimp squirrel visual-studio-code libreoffice virtualbox openshot-video-editor
#macx86 app
brew cask install clover-configurator kext-utility hwsensors
#cli app
brew install ncdu nodejs  go htop proxychains-ng mit-scheme #/usr/local/etc/proxychains.conf
#docker for amd-osx amd not support docker-ce
brew cask install docker-toolbox
#gnu
brew install evince macvim qemu
# android
brew cask install android-studio # android-ndk android-sdk
# dotnet
brew cask install dotnet-sdk
# v2ray
brew tap v2ray/v2ray
brew install v2ray-core
# need to add sudo before brew services
sudo brew services start v2ray-core
cp ~/config.json /usr/local/etc/v2ray/config.json
