#/bin/bash
cd ~
wget -O vscode.deb  https://github.com/stevedesmond-ca/vscode-arm/releases/download/1.28.2/vscode-1.28.2.deb
sudo dpkg -i vscode.deb
sudo apt install -f
rm -f vscode.deb

# hack libs for vnc run
sudo cp /usr/lib/arm-linux-gnueabihf/libxcb.so.1.1.0 /usr/share/code/
cd /usr/share/code/
sudo ln -s libxcb.so.1.1.0  libxcb.so
sudo ln -s libxcb.so.1.1.0  libxcb.so.1
sudo sed -i 's/BIG-REQUESTS/_IG-REQUESTS/' libxcb.so.1.1.0

