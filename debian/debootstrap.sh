#!/bin/bash
sudo apt install debootstrap -y
sudo debootstrap --foreign --arch mipsel stable ~/debian_mipsel http://mirrors.ustc.edu.cn/debian
dd if=/dev/zero of=debian-mipsel.img bs=1M count=4095 
mkfs.ext4 debian-mipsel.img
