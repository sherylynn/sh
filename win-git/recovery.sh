#!/bin/bash
cd ~
sudo apt install pigz -y
tar -I pigz -xvf ~/download/backup.tar.gz
