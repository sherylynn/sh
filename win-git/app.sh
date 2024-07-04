#sudo apt install libgccjit0 libgccjit-8-dev librime-dev -y
sudo apt install librime-dev -y
#for librime in deepin
if [ -f /usr/share/applications/deepin/dde-mimetype.list ]; then
    ln -s /usr/lib/x86_64-linux-gnu/librime.so.1 /home/linuxbrew/.linuxbrew/lib/librime.so.1
    ln -s /usr/lib/x86_64-linux-gnu/libboost_system.so.1.67.0 /home/linuxbrew/.linuxbrew/lib/libboost_system.so.1.67.0
    ln -s /usr/lib/x86_64-linux-gnu/libboost_filesystem.so.1.67.0 /home/linuxbrew/.linuxbrew/lib/libboost_filesystem.so.1.67.0
    ln -s /usr/lib/x86_64-linux-gnu/libboost_regex.so.1.67.0 /home/linuxbrew/.linuxbrew/lib/libboost_regex.so.1.67.0
    ln -s /usr/lib/x86_64-linux-gnu/libboost_locale.so.1.67.0 /home/linuxbrew/.linuxbrew/lib/libboost_locale.so.1.67.0
    ln -s /usr/lib/x86_64-linux-gnu/libglog.so.0 /home/linuxbrew/.linuxbrew/lib/libglog.so.0
    ln -s /usr/lib/x86_64-linux-gnu/libyaml-cpp.so.0.6 /home/linuxbrew/.linuxbrew/lib/libyaml-cpp.so.0.6
    ln -s /usr/lib/x86_64-linux-gnu/libleveldb.so.1d /home/linuxbrew/.linuxbrew/lib/libleveldb.so.1d 
    ln -s /usr/lib/x86_64-linux-gnu/libmarisa.so.0  /home/linuxbrew/.linuxbrew/lib/libmarisa.so.0
    ln -s /usr/lib/x86_64-linux-gnu/libopencc.so.2  /home/linuxbrew/.linuxbrew/lib/libopencc.so.2
    ln -s /usr/lib/x86_64-linux-gnu/libicudata.so.63  /home/linuxbrew/.linuxbrew/lib/libicudata.so.63
    ln -s /usr/lib/x86_64-linux-gnu/libicui18n.so.63  /home/linuxbrew/.linuxbrew/lib/libicui18n.so.63
    ln -s /usr/lib/x86_64-linux-gnu/libicuuc.so.63  /home/linuxbrew/.linuxbrew/lib/libicuuc.so.63
    ln -s /usr/lib/x86_64-linux-gnu/libboost_chrono.so.1.67.0 /home/linuxbrew/.linuxbrew/lib/libboost_chrono.so.1.67.0
    ln -s /usr/lib/x86_64-linux-gnu/libboost_thread.so.1.67.0 /home/linuxbrew/.linuxbrew/lib/libboost_thread.so.1.67.0
    ln -s /usr/lib/x86_64-linux-gnu/libgflags.so.2.2 /home/linuxbrew/.linuxbrew/lib/libgflags.so.2.2
    ln -s /usr/lib/x86_64-linux-gnu/libunwind.so.8 /home/linuxbrew/.linuxbrew/lib/libunwind.so.8
    ln -s /usr/lib/x86_64-linux-gnu/libsnappy.so.1 /home/linuxbrew/.linuxbrew/lib/libsnappy.so.1
    ln -s /usr/lib/x86_64-linux-gnu/libboost_atomic.so.1.67.0 /home/linuxbrew/.linuxbrew/lib/libboost_atomic.so.1.67.0
fi
brew install htop ncdu vim
# for doom emacs
brew untap sherylynn/homebrew-emacsx11
brew tap sherylynn/homebrew-emacsx11
brew install emacsx11
brew install ripgrep git fd coreutils cmake libtool libvterm
# for vterm support
# brew install gcc@5
# for doom emacs orgmode support mouse or M-x xterm-mouse-mode 
brew install tmux ttyd

sudo tee /usr/share/applications/spark-store.desktop <<-'EOF'
[Desktop Entry]
Name=Emacs
GenericName=Text Editor
Comment=Edit text
MimeType=text/english;text/plain;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;
#Exec=eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && emacs %F
Exec=/home/linuxbrew/.linuxbrew/bin/emacs
Icon=emacs
Type=Application
Terminal=false
Categories=Development;TextEditor;
StartupWMClass=Emacs
EOF

sudo chmod 777 /usr/share/applications/emacs.desktop
