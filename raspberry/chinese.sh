#fuck raspbian and rime
#sudo rm -rf ~/.config/fcitx
#sudo apt install ibus-rime
#sudo apt install fcitx-rime
sudo apt install fcitx5 fcitx5-rime fonts-wqy-zenhei ttf-wqy-zenhei -y
#sudo apt install fcitx-googlepinyin -y
sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
sudo apt install locales -y
sudo locale-gen zh.cn.UTF-8
