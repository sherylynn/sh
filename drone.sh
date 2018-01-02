#!/bin/bash
sudo apt install python-pip
pip install docker-compose
sudo mkdir /etc/drone
sudo cp ~/sh/docker-compose.yml /etc/drone/
docker-compose -f /etc/drone/docker-compose.yml up