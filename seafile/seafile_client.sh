# for debian
#sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 8756C4F765C9AC3CB6B85D62379CE192D401AB61

#echo deb http://deb.seadrive.org stretch main | sudo tee /etc/apt/sources.list.d/seafile.list

#sudo apt update

#sudo apt install seafile-gui
# for ubuntu
#sudo add-apt-repository ppa:seafile/seafile-client

#sudo apt-get update

#sudo apt-get install seafile-gui
### miss for 19.10 just for 19.04 disco
###  echo deb http://ppa.launchpad.net/seafile/seafile-client/ubuntu disco main |sudo tee /etc/apt/sources.list.d/seafile-ubuntu-seafile-client-eoan.list


sudo wget https://linux-clients.seafile.com/seafile.asc -O /usr/share/keyrings/seafile-keyring.asc
sudo bash -c "echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/seafile-keyring.asc] https://linux-clients.seafile.com/seafile-deb/buster/ stable main' > /etc/apt/sources.list.d/seafile.list"
sudo apt update
sudo apt install -y seafile-gui
