#!/bin/bash
if [ -f "$HOME/swap" ]; then
  echo "swap on"
else
  dd if=/dev/zero of=$HOME/swap bs=1024 count=1000000
  mkswap -f $HOME/swap
  sudo swapon $HOME/swap
  echo '/home/'${USER}'/swap swap swap defaults 0 0' |sudo tee -a /etc/fstab
fi
