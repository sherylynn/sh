#sudo apt install gperf libluajit-5.1-dev libunibilium-dev libmsgpack-dev libtermkey-dev libvterm-dev libjemalloc-dev -y
sudo apt-get install ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip -y
cd ~
git clone https://github.com/neovim/neovim
##
cd neovim
#core_num=$(cat /proc/cpuinfo|grep "processer"|wc -l)
core_num=$(nproc)
if [[ ${BUILD_TYPE} =~ (DEBUG) ]]; then
  mkdir -p .deps
  cd .deps
  cmake ../third-party
  cd ..
  mkdir -p build
  cd build
  cmake ..
  make -j$core_num
  sudo make install
elif [[ ${BUILD_TYPE} =~ (RELEASE) ]]; then
  rm -rf build
  make clean
  make CMAKE_BUILD_TYPE=Release -j$core_num
  sudo make install
else
  rm -rf build
  make CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$HOME/neovim" -j$core_num
  make install
  if [[ $(cat ~/.bashrc) != *neovim* ]]; then
    echo export PATH="$HOME/neovim/bin:$PATH">>~/.bashrc
  fi
fi
