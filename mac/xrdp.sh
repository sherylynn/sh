# prerequisites
brew install openssl automake libtool pkgconfig nasm
brew cask install xquartz
cd ~
git clone https://github.com/neutrinolabs/xrdp
cd xrdp
./bootstrap
./configure PKG_CONFIG_PATH=/usr/local/opt/openssl/lib/pkgconfig
make
sudo make install
cd ~
git clone https://github.com/neutrinolabs/xorgxrdp
cd xorgxrdp
./bootstrap
./configure PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig
make
sudo make install
# success build and install but turn to black screen
