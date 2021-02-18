#!/bin/bash
if [ $1 ]; then
  G=$1
else
  G=1
fi
if [ -f "$HOME/swap" ]; then
  echo "swap on"
else
  dd if=/dev/zero of=$HOME/swap bs=1024 count=${G}000
  mkswap -f $HOME/swap
fi
swapon $HOME/swap
echo '/opt/home/admin/swap swap swap defaults 0 0' |tee -a /etc/mtab
