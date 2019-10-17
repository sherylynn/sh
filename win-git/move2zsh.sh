#!/bin/bash
. $(dirname "$0")/toolsinit.sh
echo $(bash_file)
cat $(bash_file) |grep test >$(alltoolsrc_file)
