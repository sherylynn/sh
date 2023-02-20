#!/bin/bash
. $(dirname "$0")/toolsinit.sh
#TOFILE=~/download/config.yaml
TODIR=/tmp/share
mkdir -p $TODIR
TOFILE=$TODIR/config.yaml
cat ~/config.yaml > $TOFILE
echo "  '8t': $(hotspot_ip)" >> $TOFILE
echo "  'oneplus.8t': $(hotspot_ip)" >> $TOFILE
echo "  'one.plus.8t': $(hotspot_ip)" >> $TOFILE
http-server $TODIR

