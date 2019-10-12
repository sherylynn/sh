#------------------init function----------------
. $(dirname "$0")/../win-git/toolsinit.sh
#sudo apt install gperf libluajit-5.1-dev libunibilium-dev libmsgpack-dev libtermkey-dev libvterm-dev libjemalloc-dev -y
sudo apt-get install ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip -y
cd ~
git clone https://github.com/neovim/neovim
##
cd neovim
git checkout v0.4.2
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
  sudo apt install gperf libluajit-5.1-dev libunibilium-dev libmsgpack-dev libtermkey-dev libjemalloc-dev libuv1-dev lua-lpeg-dev lua-mpack lua-luv-dev libutf8proc-dev -y 
  #sudo apt install libvterm-dev -y
  cd ~ 
  git clone https://github.com/neovim/libvterm 
  make
  sudo make install
  cd ~
  git clone https://github.com/luvit/luv.git --recursive
  cd luv
  mkdir -p include/luv
  cp src/* include/luv/
  BUILD_MODULE=OFF BUILD_SHARED_LIBS=ON make
  sudo make install

  #还需要lua的bit库，没法直接安装，只有编译安装
  cd ~
  cd neovim
  sudo apt install lua-bitop-dev -y
  rm -rf .deps
  mkdir -p build 
  cd build
  if [[ ${MAKE_TYPE} =~ (NINJA) ]]; then
    cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=$HOME/neovim/build -DLIBLUV_LIBRARY:STRING=-Wl,/usr/lib/$(arch)-$(platform)-gnu/liblua5.1-luv.so -DLIBLUV_INCLUDE_DIR=/usr/include/lua5.1 -DLIBVTERM_INCLUDE_DIR=/usr/local/include -DLIBVTERM_LIBRARY=/usr/local/lib/libvterm.so
    ninja
    ninja install
  else
    cmake ..  -DCMAKE_INSTALL_PREFIX=$HOME/neovim/build -DLIBLUV_LIBRARY=$HOME/luv/build/luv.so -DLIBLUV_INCLUDE_DIR=$HOME/luv/include
    make -j
    make install
  fi
  #最后绕了一圈发现nvim的python支持不是build来的，默认的就是没的
  #需要pip3 install --user neovim
  #修改成pynvim了
  if [[ $(cat ~/.bashrc) != *neovim/build* ]]; then
    echo export PATH="$HOME/neovim/build/bin:"'$PATH'>>~/.bashrc
  fi
fi
