#/bin/bash
if [ ! -d "$HOME/gogs_data" ];then
mkdir $HOME/gogs_data
if

docker run -itd --name gogs --restart=always -p 10022:22 -p 10080:3000 -v $HOME/gogs_data:/data gogs/gogs