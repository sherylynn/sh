#!/bin/bash
# source
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=calibrerc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
CALIBRE_ROOT="/C/Program\ Files/Calibre2"
echo 'export PATH=$PATH:'${CALIBRE_ROOT} > ${TOOLSRC}
