#curl -o hsk.deb https://hsk.oray.com/download/download?id=25
# depends on armhf arm64 will need libstdc++.so.6
wget -O hsk.deb https://hsk.oray.com/download/download?id=25
sudo apt install libstdc++6:armhf
sudo dpkg -i hsk.deb
