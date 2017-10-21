sudo apt install docker.io
docker run -itd --name v2ray --net=host -v $HOME:/etc/v2ray v2ray/official