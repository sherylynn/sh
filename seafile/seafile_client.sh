sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 8756C4F765C9AC3CB6B85D62379CE192D401AB61

echo deb http://deb.seadrive.org stretch main | sudo tee /etc/apt/sources.list.d/seafile.list

sudo apt update

sudo apt install seafile-gui
