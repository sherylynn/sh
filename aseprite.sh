cd ~
sudo apt-get update -qq
sudo apt-get install -y g++ libx11-dev libxcursor-dev cmake ninja-build
git clone --recursive https://github.com/aseprite/aseprite.git
cd aseprite
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=~/tools/aseprite -G Ninja ..
ninja aseprite
ninja install
