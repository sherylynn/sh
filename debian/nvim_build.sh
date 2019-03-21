#sudo apt install gperf libluajit-5.1-dev libunibilium-dev libmsgpack-dev libtermkey-dev libvterm-dev libjemalloc-dev -y
sudo apt-get install ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip -y
cd ~
git clone https://github.com/neovim/neovim
cd neovim
mkdir -p .deps
cd .deps
cmake ../third-party
#core_num=$(cat /proc/cpuinfo|grep "processer"|wc -l)
core_num=$(nproc)
make -j$core_num
cd ..
mkdir -p build
cd build
cmake ..
make -j$core_num
