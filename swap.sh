#!/bin/bash
if [ $1 ]; then
  G=$1
else
  G=1
fi
if [ -f "$HOME/swap" ]; then
  echo "swap on"
else
  dd if=/dev/zero of=$HOME/swap bs=1024 count=${G}000000
  sudo mkswap -f $HOME/swap
fi
sudo swapon $HOME/swap
echo '/home/'${USER}'/swap swap swap defaults 0 0' |sudo tee -a /etc/fstab
