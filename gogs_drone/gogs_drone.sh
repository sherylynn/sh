#/bin/bash
#把gogs和drone都迁移到一起去
if [ ! -f "/usr/local/bin/drone" ]; then
    curl -L https://github.com/drone/drone-cli/releases/download/v0.8.0/drone_linux_amd64.tar.gz | tar zx
    sudo install -t /usr/local/bin drone
fi

if [ ! -f "/usr/local/bin/docker-compose" ]; then
    sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    sudo chmod 777 /usr/local/bin/docker-compose
fi
#如果存在就迁移
if [ -d "/etc/drone" ]; then
    #sudo /usr/local/bin/docker-compose -f /etc/drone/docker-compose.yml stop
    sudo systemctl stop drone.service
    sudo systemctl disable drone.service
    docker rm drone_drone-server_1
    docker rm drone_drone-agent_1
    sudo mv /etc/drone $HOME/drone
fi