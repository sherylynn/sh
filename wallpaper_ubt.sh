#!/bin/bash

Size=1000
Url=http://picsum.photos/${Size}/?random
WALLS_PATH=$HOME/Wallpapers
cd $WALLS_PATH

wget $Url -O $HOME/Wallpapers/${Size}.jpg

gsettings set org.gnome.desktop.background picture-uri "file://$HOME/Wallpapers/${Size}.jpg"
