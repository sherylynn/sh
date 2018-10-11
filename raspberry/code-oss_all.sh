wget -O code-oss_armhf.deb --content-disposition https://packagecloud.io/headmelted/codebuilds/packages/ubuntu/xenial/code-oss_1.28.0-1537780162_armhf.deb/download.deb
sudo dpkg -i code-oss_armhf.deb
sudo apt install -f
rm -f code-oss_armhf.deb
