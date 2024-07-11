#!/bin/bash
. $(dirname "$0")/../win-git/toolsinit.sh
pkg install termux-services -y
pkg install ttyd -y

zsh ~/sh/termux/termux_service_ttyd.sh
sh ~/sh/termux/termux_service_ttyd.sh
  sv-enable ttyd
