#sudo apt install docker.io
#sudo docker run -itd --name v2ray --net=host -v $HOME:/etc/v2ray v2ray/official
docker run -itd --name v2ray --restart=always --net=host -v $HOME:/etc/v2ray v2ray/official
