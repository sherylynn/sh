#!/bin/bash
. $(dirname "$0")/toolsinit.sh
cd ~
sudo apt install pigz -y
tar -I pigz -xvf ~/download/backup_$(arch).tar.gz
