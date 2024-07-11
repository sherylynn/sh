#!/data/data/com.termux/files/usr/bin/bash
pkg install emacs -y
sv-enable emacsd
#pkg install gh fd ripgrep -y
if [ ! -f "~/.emacs.d/elpa/vterm-2*/vterm-module.so" ]; then
    echo "need to download vterm and rime build deps"
    pkg install cmake build-essential wget tsu -y
fi

if [ ! -f "~/.emacs.d/elpa/rime-2*/librime-emacs.so" ]; then
    echo "need to download vterm and rime build deps"
    pkg install cmake build-essential wget tsu -y
fi

pkg install librime libvterm -y
