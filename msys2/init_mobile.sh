#!/bin/bash
#pacman -Sy
#pacman -Su
if command -v git >/dev/null 2>&1; then
  echo 'git exists'
else
  pacman -S git unzip zip tar
fi
#pacman -S mingw64/mingw-w64-x86_64-lua
#------------------init function----------------
. $(dirname "$0")/../win-git/toolsinit.sh
#. $(dirname "$0")/../win-git/winPath.sh
INSTALL_PATH=$HOME/tools
TOOLSRC_NAME=msys2rc
TOOLSRC=$(toolsRC $TOOLSRC_NAME)
#echo 'export HOME='$(winPath $USERPROFILE)> $TOOLSRC
#echo 'export HOME='$(cygpath -u $USERPROFILE)> $TOOLSRC

vim /etc/nsswitch.conf -c '%s#db_home: cygwin desc#db_home: /home/lynn#g' -c':wq!'
#sed -i 's/: cygwin/: windows cygwin/g' /etc/nsswitch.conf
echo "SHELL=/usr/bin/zsh" >> /mingw64.ini
