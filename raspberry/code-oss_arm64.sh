wget -O code-oss_arm64.deb --content-disposition https://packagecloud.io/headmelted/codebuilds/packages/ubuntu/xenial/code-oss_1.28.0-1537780154_arm64.deb/download.deb
sudo dpkg -i code-oss_arm64.deb
sudo apt install -f
rm -f code-oss_arm64.deb
sudo ln -sf /usr/bin/code-oss /usr/bin/code
#suit for sync extension
sudo mkdir -p /usr/share/code/bin
sudo ln -sf /usr/share/code-oss/bin/code-oss /usr/share/code/bin/code
sudo ln -sf /usr/share/code-oss/bin/code-oss /usr/share/code-oss/bin/code
# hack libs for vnc run
sudo cp /usr/lib/aarch64-linux-gnu/libxcb.so.1.1.0 /usr/share/code-oss/
cd /usr/share/code-oss/
sudo ln -s libxcb.so.1.1.0  libxcb.so
sudo ln -s libxcb.so.1.1.0  libxcb.so.1
sudo sed -i 's/BIG-REQUESTS/_IG-REQUESTS/' libxcb.so.1.1.0

