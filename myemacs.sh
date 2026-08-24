#!/bin/bash
. $(dirname "$0")/win-git/toolsinit.sh
NAME=my
TOOLSRC_NAME=${NAME}rc
TOOLSRC=$(toolsRC ${TOOLSRC_NAME})
#rm ~/.emacs.d
rm -rf ~/.emacs.d
#git clone --depth 1 https://github.com/plexus/chemacs2.git ~/.emacs.d
git clone --depth 1 https://github.com/sherylynn/myemacs.d.git ~/.emacs.d_my
ln -s ~/.emacs.d_my ~/.emacs.d

git clone --depth 1 https://github.com/iDvel/rime-ice ~/rime
sudo rm -rf /usr/share/rime-data
sudo ln -s ~/rime /usr/share/rime-data
#ln -s ~/.emacs.d_doom ~/.emacs.d
#git clone https://github.com/sherylynn/doom-private ~/.doom.d
#~/.emacs.d_doom/bin/doom install

tee ~/.emacs-profiles.el <<-'EOF'
(("default"   . ((user-emacs-directory . "~/.emacs.d_my")))
 ("doom" . ((user-emacs-directory . "~/.emacs.d_doom")))
 ("space"   . ((user-emacs-directory . "~/.emacs.d_space"))))
EOF
#SOFT_BIN=~/.emacs.d_doom/bin
#echo 'export PATH=$PATH:'${SOFT_BIN}>${TOOLSRC}


# Configure XFCE text-file associations to use the GUI Emacs built above.
if [[ "${XDG_CURRENT_DESKTOP,,}" == *xfce* || "${DESKTOP_SESSION,,}" == *xfce* || -n "${XFCE4_SESSION_ID:-}" ]]; then
    APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    mkdir -p "$APP_DIR"

    tee "$APP_DIR/myemacs.desktop" >/dev/null <<'EOF'
[Desktop Entry]
Version=1.0
Name=My Emacs
GenericName=Text Editor
Comment=GNU Emacs using my configuration
Type=Application
Exec=/usr/bin/emacs %F
TryExec=/usr/bin/emacs
Terminal=false
StartupNotify=true
StartupWMClass=Emacs
Icon=emacs
Categories=Utility;Development;TextEditor;
MimeType=text/plain;text/english;text/x-makefile;text/x-c;text/x-c++;text/x-java;text/x-shellscript;
EOF

    if command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default myemacs.desktop text/plain
        xdg-mime default myemacs.desktop text/english
        xdg-mime default myemacs.desktop text/x-makefile
        xdg-mime default myemacs.desktop text/x-c
        xdg-mime default myemacs.desktop text/x-c++
        xdg-mime default myemacs.desktop text/x-java
        xdg-mime default myemacs.desktop text/x-shellscript
    fi

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
    fi
fi
