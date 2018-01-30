#/bin/bash
sudo apt install dos2unix -y
mv .git ~/.git_bak
find . -type f -exec dos2unix {} \;
mv ~/.git_bak .git