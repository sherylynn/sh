#!/bin/bash
sudo rm -f /boot/grub/custom.cfg
sudo ln -s $(dirname  $(readlink -f "$0"))/custom.cfg /boot/grub/custom.cfg
