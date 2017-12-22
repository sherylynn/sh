#!/bin/bash

Size=1000
Url=http://picsum.photos/${Size}/?random
WALLS_PATH=$HOME/Wallpapers
if [ ! -d "${WALLS_PATH}" ]; then
mkdir $WALLS_PATH
fi
wget $Url -O $HOME/Wallpapers/${Size}.jpg

gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Wallpapers/${Size}.jpg"
