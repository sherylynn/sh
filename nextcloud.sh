#!/bin/bash
mkdir ~/data
mkdir ~/data/cloud
mkdir ~/data/cloud/mysql
mkdir ~/data/cloud/config
mkdir ~/data/cloud/apps
mkdir ~/data/cloud/data

docker-compose -f ./sh/nextcloud.yml up -d
#docker-compose -f ./sh/nextcloud.yml stop