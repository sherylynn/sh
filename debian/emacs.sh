#!/bin/bash
set -euo pipefail

# NewHome CHROOT is Wayland-first. Debian's generic "emacs" dependency prefers
# emacs-gtk (X11-only), which needlessly routes Emacs through managed XWayland.
# PGTK is the native Wayland build and keeps the same emacs-common configuration.
sudo apt install emacs-pgtk -y
#apt install gh fd ripgrep -y
sudo apt install cmake libvterm-dev librime-dev -y
sudo apt install build-essential -y
sudo apt install shfmt -y
