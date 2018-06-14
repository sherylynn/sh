#记得在微软visual stuidio的开发者cmd中执行，不然不生效
cd ~
git clone --recursive https://github.com/aseprite/aseprite.git
cd aseprite
mkdir build
cd build
cmake -G Ninja ..
