#!/bin/bash
cd ~
sudo apt install pigz -y
#npm cache clean --force
mkdir -p ~/download
#tar -zpcvf ~/download/backup.tar.gz --exclude=download --exclude=.cache ./*
#tar -pcvf ~/download/backup.tar.gz --exclude=download --exclude=.cache -I pigz ./*

#tar --use-compress-program="pigz -9" -pcvf ~/download/backup.tar.gz --exclude=download --exclude=.cache  ./*
tar --exclude=download --exclude=.cache  -pcvf - ./*  |pigz --best > ~/download/backup.tar.gz
