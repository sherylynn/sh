rm /data/data/org.gnu.emacs/files
ln -s /data/data/com.termux/files/home /data/data/org.gnu.emacs/files
rm /data/data/com.termux/files/home/fonts
ln -s /data/data/com.termux/files/home/.local/share/fonts /data/data/com.termux/files/home/fonts
rm /data/data/com.termux/files/home/fonts/font.ttf
ln -s /data/data/com.termux/files/home/.termux/font.ttf /data/data/com.termux/files/home/fonts/font.ttf
