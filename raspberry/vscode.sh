#/bin/bash
cd ~
wget -O vscode.deb  https://github.com/stevedesmond-ca/vscode-arm/releases/download/1.28.0/vscode-1.28.0.deb
sudo dpkg -i vscode.deb
sudo apt install -f
rm -f vscode.deb
