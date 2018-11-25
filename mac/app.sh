#/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew tap caskroom/cask
#normal app
brew cask install onyx skim iina firefox chromium calibre v2rayx qq wechat anydesk teamviewer visual-studio-code telegram-desktop steam gimp squirrel visual-studio-code libreoffice virtualbox
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
