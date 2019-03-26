#sudo apt install gperf libluajit-5.1-dev libunibilium-dev libmsgpack-dev libtermkey-dev libvterm-dev libjemalloc-dev -y
sudo apt-get install ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip -y
cd ~
git clone https://github.com/neovim/neovim
##
cd neovim
git checkout v0.3.4
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
elif [[ ${BUILD_TYPE} =~ (BUNDLE) ]]; then
  rm -rf build
  make CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$HOME/neovim" -j$core_num
  make install
  if [[ $(cat ~/.bashrc) != *neovim* ]]; then
    echo export PATH="$HOME/neovim/bin:"'$PATH'>>~/.bashrc
  fi
else
  #有lua5.3的情况下编译不了
  #arm64的情况下没法直接编译nvim因为lua用默认脚本提示不支持arm64
  sudo apt remove lua5.3 -y
  sudo apt install lua5.1 -y
  sudo apt install gperf libluajit-5.1-dev libunibilium-dev libmsgpack-dev libtermkey-dev libvterm-dev libjemalloc-dev libuv1-dev lua-lpeg-dev lua-mpack -y 
  #还需要lua的bit库，没法直接安装，只有编译安装
  rm -rf .deps
  mkdir -p build 
  cd build
  cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=$HOME/neovim/build
  ninja
  ninja install
  #最后绕了一圈发现nvim的python支持不是build来的，默认的就是没的
  #需要pip3 install --user neovim
  if [[ $(cat ~/.bashrc) != *neovim/build* ]]; then
    echo export PATH="$HOME/neovim/build/bin:"'$PATH'>>~/.bashrc
  fi
fi
