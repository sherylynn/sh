cd ~
git clone https://github.com/ventoy/vtoyboot
cd vtoyboot/vtoyboot
git checkout .
git pull
echo "your password"
sudo apt install grub-pc-bin
sudo bash ~/vtoyboot/vtoyboot/vtoyboot.sh
