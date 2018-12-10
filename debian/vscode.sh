#/bin/bash
cd ~
wget -O vscode.deb https://go.microsoft.com/fwlink/?LinkID=760868
sudo dpkg -i vscode.deb
sudo apt install -f
rm -f vscode.deb
