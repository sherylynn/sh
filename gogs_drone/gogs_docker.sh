#/bin/bash
if [ ! -d "$HOME/gogs_data" ];then
mkdir $HOME/gogs_data
fi
if [ -d "$HOME/gogs" ];then
sudo systemctl stop gogs.service
sudo systemctl disable gogs.service
sudo chown -R ${USER} $HOME/gogs
sudo chown -R ${USER} $HOME/gogs-repositories
sudo chgrp -R ${USER} $HOME/gogs
sudo chgrp -R ${USER} $HOME/gogs-repositories
mv $HOME/gogs/custom $HOME/gogs_data/gogs
mv $HOME/gogs/data $HOME/gogs_data/gogs/
mv $HOME/gogs/log $HOME/gogs_data/gogs/
#-i 是直接修改 不带的话输出到屏幕 带变量需要在变量两边加单引号
sed -i 's/'$USER'/git/g' $HOME/gogs_data/gogs/conf/app.ini
sed -i 's/home/data/g' $HOME/gogs_data/gogs/conf/app.ini
sed -i '46c ROOT_PATH = /app/gogs/log' $HOME/gogs_data/gogs/conf/app.ini  
fi
if [ -d "$HOME/gogs-repositories" ];then
mv $HOME/gogs-repositories $HOME/gogs_data/git/gogs-repositories
fi
docker run -itd --name gogs --restart=always -p 22000:22 -p 3000:3000 -v $HOME/gogs_data:/data gogs/gogs

