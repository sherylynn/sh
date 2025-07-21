# runtime dependencies
sudo apt install -y ffmpeg libsdl2-2.0-0 adb

# client build dependencies
sudo apt install -y gcc git pkg-config meson ninja-build ccache \
                 libavcodec-dev libavformat-dev libavutil-dev \
                 libsdl2-dev

# server build dependencies
#Csudo apt install openjdk-8-jdk
sudo apt install -y openjdk-11-jdk
cd ~
git clone https://github.com/Genymobile/scrcpy
cd scrcpy