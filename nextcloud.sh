#!/bin/bash
mkdir ~/data
mkdir ~/data/cloud
mkdir ~/data/cloud/mysql
mkdir ~/data/cloud/cofig
mkdir ~/data/cloud/apps
mkdir ~/data/cloud/data

docker-compose -f ./sh/nextcloud.yml up -d