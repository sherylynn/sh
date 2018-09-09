snap install vscode --classic
sudo ln -s /var/lib/snapd/snap /snap
echo 'export PATH=/snap/bin:$PATH' >> ~/.bashrc
source ~/.bashrc