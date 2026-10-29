#!/bin/bash
#pacman -Sy
#pacman -Su
if command -v git >/dev/null 2>&1; then
  echo 'git exists'
else
  pacman -S git unzip zip tar
fi
#pacman -S mingw64/mingw-w64-x86_64-lua
# fd and ripgrep live in MinGW64; expose them to the default MSYS zsh PATH.
pacman -S --needed --noconfirm mingw-w64-x86_64-fd mingw-w64-x86_64-ripgrep || exit $?
mkdir -p /usr/local/bin || exit $?
cat > /usr/local/bin/fd <<'EOF'
#!/bin/sh
exec /mingw64/bin/fd.exe "$@"
EOF
cat > /usr/local/bin/rg <<'EOF'
#!/bin/sh
exec /mingw64/bin/rg.exe "$@"
EOF
chmod +x /usr/local/bin/fd /usr/local/bin/rg || exit $?
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
