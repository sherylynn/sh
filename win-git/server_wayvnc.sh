#!/bin/bash
export DISPLAY=:0
export XDG_RUNTIME_DIR="/tmp/wayvnc"
mkdir -p $XDG_RUNTIME_DIR
chmod 0700 $XDG_RUNTIME_DIR
wayvnc 0.0.0.0
