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
mv $HOME/gogs/logs $HOME/gogs_data/gogs/
sed 's/${USER}/git/g' /gogs_data/gogs/conf/app.ini
sed 's/home/data/g' /gogs_data/gogs/conf/app.ini
sed '46c ROOT_PATH = /app/gogs/log' /gogs_data/gogs/conf/app.ini  
fi
if [ -d "$HOME/gogs-repositories" ];then
mv $HOME/gogs-repositories $HOME/gogs_data/git/
fi
docker run -itd --name gogs --restart=always -p 22000:22 -p 3000:3000 -v $HOME/gogs_data:/data gogs/gogs

