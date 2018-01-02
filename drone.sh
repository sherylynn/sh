#!/bin/bash
sudo apt install python-pip
pip install docker-compose
sudo mkdir /etc/drone
sudo cp ~/sh/docker-compose.yml /etc/drone/

sudo tee /etc/drone/drone.env <<-"EOF"
GOGS_HOST=http://111.231.90.43:3000/
DRONE_ENV_HOST=http://111.231.90.43/
EOF
echo DRONE_ENV_SECRET="$(LC_ALL=C </dev/urandom tr -dc A-Za-z0-9 | head -c 65)" |sudo tee -a /etc/drone/drone.env

docker-compose -f /etc/drone/docker-compose.yml up