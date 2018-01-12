sudo snap install docker
if [ ! -f "/usr/local/bin/docker-compose" ]; then
    sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    sudo chmod 777 /usr/local/bin/docker-compose
fi