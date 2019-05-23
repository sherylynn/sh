#!/bin/bash
. $(dirname "$0")/toolsinit.sh
TOOLSRC_NAME=autosshpassrc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)
PLATFORM=$(platform)
#---------------------------------------------
if [[ "$PLATFORM" == *win* ]]; then
  cat <<EOF > $TOOLSRC
  eval \$(ssh-agent)
EOF
else
  cat <<EOF > $TOOLSRC
  ps -ef |grep ssh-agent |grep -v grep &> /dev/null ||eval \$(ssh-agent)
EOF
fi
#---------------------------------------------
