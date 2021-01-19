#常用工具
sudo apt install ssh tofrodos htop ncdu vim aria2 -y

#fromdos xxx

#更新vbox源
sudo apt install apt-transport-https ca-certificates gnupg2  software-properties-common curl -y


curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo apt-key add -
sudo add-apt-repository \
    "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian \
    $(lsb_release -cs) \
    contrib"
#安装vbox
sudo apt update
sudo apt install virtualbox-6.1 -y
