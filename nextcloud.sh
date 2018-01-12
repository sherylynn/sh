#!/bin/bash
mkdir ~/data
mkdir ~/data/cloud
mkdir ~/data/cloud/mysql
mkdir ~/data/cofig
mkdir ~/data/apps

docker-compose -f ./sh/nextcloud.yml up -d