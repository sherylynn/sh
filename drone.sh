#!/bin/bash
sudo apt install python-pip
pip install docker-compose

if [ ! -d "/etc/drone" ]; then
    sudo mkdir /etc/drone
fi

sudo cp ~/sh/docker-compose.yml /etc/drone/

sudo tee /etc/drone/drone.env <<-"EOF"
DRONE_HOST=http://111.231.90.43/
DRONE_GOGS_URL=http://111.231.90.43:3000/
EOF

if [ $DRONE_SECRET ];then  
    echo DRONE_SECRET=$DRONE_SECRET |sudo tee -a /etc/drone/drone.env
else
    DRONE_ENV_SECRET="$(LC_ALL=C </dev/urandom tr -dc A-Za-z0-9 | head -c 65)"
    echo DRONE_SECRET=${DRONE_ENV_SECRET}|sudo tee -a /etc/drone/drone.env
    #echo DRONE_SECRET="$(LC_ALL=C </dev/urandom tr -dc A-Za-z0-9 | head -c 65)" |sudo tee -a /etc/drone/drone.env
    echo export DRONE_SECRET=${DRONE_ENV_SECRET}|sudo tee -a $HOME/.bashrc
fi 

if [ $DRONE_HOST ];then  
    echo DRONE_HOST=$DRONE_HOST |sudo tee -a /etc/drone/drone.env
else
    echo export DRONE_HOST=http://111.231.90.43/|sudo tee -a $HOME/.bashrc
fi 


if [ $DRONE_GOGS_URL ];then  
    echo DRONE_GOGS_URL=$DRONE_GOGS_URL |sudo tee -a /etc/drone/drone.env
else
    echo export DRONE_GOGS_URL=http://111.231.90.43:3000/|sudo tee -a $HOME/.bashrc
fi 

docker-compose -f /etc/drone/docker-compose.yml up