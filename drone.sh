#!/bin/bash
sudo apt install python-pip
pip install docker-compose
sudo mkdir /etc/drone
sudo cp ~/sh/docker-compose.yml /etc/drone/

sudo tee /etc/drone/drone.env <<-"EOF"
DRONE_HOST=http://111.231.90.43/
DRONE_GOGS_URL=http://111.231.90.43:3000/
EOF

if [ $DRONE_SECRET ];then  
    echo DRONE_SECRET=$DRONE_SECRET |sudo tee -a /etc/drone/drone.env
else  
    echo DRONE_SECRET="$(LC_ALL=C </dev/urandom tr -dc A-Za-z0-9 | head -c 65)" |sudo tee -a /etc/drone/drone.env
fi 


docker-compose -f /etc/drone/docker-compose.yml up