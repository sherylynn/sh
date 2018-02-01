#/bin/bash
if [ ! -d "$HOME/gogs_data" ];then
mkdir $HOME/gogs_data
fi
docker run -itd --name gogs --restart=always -p 22000:22 -p 3000:3000 -v $HOME/gogs_data:/data gogs/gogs

